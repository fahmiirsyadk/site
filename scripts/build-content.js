import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import yaml from "js-yaml";
import MarkdownIt from "markdown-it";

const md = new MarkdownIt({ html: true, linkify: true, typographer: true });

const rootDir = process.cwd();
const contentDir = path.join(rootDir, "content");
const generatedDir = path.join(rootDir, "generated");
const outputPath = path.join(generatedDir, "posts.json");

async function readMarkdownCollection(sectionPath) {
  let entries = [];
  try {
    entries = await fs.readdir(sectionPath, { withFileTypes: true });
  } catch {
    return [];
  }

  const markdownFiles = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join(sectionPath, entry.name));

  const docs = await Promise.all(markdownFiles.map((file) => parseMarkdownFile(file)));
  return docs.filter(Boolean);
}

async function parseMarkdownFile(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  const { frontmatter, body } = splitFrontmatter(raw);
  const slug = frontmatter.slug || path.basename(filePath, ".md");

  return {
    slug,
    frontmatter,
    body,
  };
}

function splitFrontmatter(raw) {
  const match = raw.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) {
    return { frontmatter: {}, body: raw };
  }

  return {
    frontmatter: yaml.load(match[1]) || {},
    body: match[2] || "",
  };
}

function isoDate(value) {
  if (!value) return new Date(0).toISOString();
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return new Date(0).toISOString();
  return date.toISOString();
}

function excerptFromBody(body) {
  const trimmed = body
    .replace(/[#>*`_\-\[\]\(\)]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!trimmed) return "";
  return trimmed.slice(0, 180);
}

function slugify(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/<[^>]+>/g, "")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

function shouldIncludeTocHeading(title, idBase) {
  const normalized = String(title || "").trim().toLowerCase();
  if (!normalized) return false;
  if (normalized === "table of contents") return false;
  if (normalized === "toc") return false;
  if (idBase === "table-of-contents") return false;
  return true;
}

function renderBodyWithToc(body) {
  const tokens = md.parse(body, {});
  const toc = [];
  const seen = new Map();

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.type !== "heading_open") continue;

    const level = Number(token.tag.slice(1));
    const inline = tokens[i + 1];
    if (!inline || inline.type !== "inline") continue;

    const title = (inline.content || "").trim();
    let idBase = slugify(title) || "section";
    const count = seen.get(idBase) || 0;
    seen.set(idBase, count + 1);
    const id = count === 0 ? idBase : `${idBase}-${count + 1}`;

    token.attrSet("id", id);

    if (level >= 2 && level <= 3 && shouldIncludeTocHeading(title, idBase)) {
      toc.push({ id, title, level });
    }
  }

  return {
    bodyHtml: md.renderer.render(tokens, md.options, {}),
    toc,
  };
}

function toPost(doc, section, extraTags = []) {
  const fm = doc.frontmatter;
  const rendered = renderBodyWithToc(doc.body);
  const baseTags = Array.isArray(fm.tags) ? fm.tags : [];
  const tags = [...new Set([...baseTags, ...extraTags])];
  return {
    slug: doc.slug,
    title: fm.title || doc.slug,
    date: isoDate(fm.date),
    description: fm.description || "",
    toc: rendered.toc,
    section,
    tags,
    excerpt: fm.excerpt || excerptFromBody(doc.body),
    bodyHtml: rendered.bodyHtml,
  };
}

function toThought(doc) {
  const fm = doc.frontmatter;
  return {
    slug: doc.slug,
    title: fm.title || "Note",
    date: isoDate(fm.date),
    status: fm.status || "published",
    pinned: Boolean(fm.pinned),
    excerpt: fm.excerpt || excerptFromBody(doc.body),
    bodyHtml: md.render(doc.body),
  };
}

function byDateDesc(a, b) {
  return new Date(b.date).getTime() - new Date(a.date).getTime();
}

async function main() {
  const [articleDocs, projectDocs, tilDocs, thoughtDocs] = await Promise.all([
    readMarkdownCollection(path.join(contentDir, "articles")),
    readMarkdownCollection(path.join(contentDir, "projects")),
    readMarkdownCollection(path.join(contentDir, "til")),
    readMarkdownCollection(path.join(contentDir, "thoughts")),
  ]);

  const articles = articleDocs
    .filter((doc) => (doc.frontmatter.status || "published") === "published")
    .map((doc) => toPost(doc, "articles"))
    .sort(byDateDesc);

  const projects = projectDocs
    .filter((doc) => (doc.frontmatter.status || "published") === "published")
    .map((doc) => toPost(doc, "projects"))
    .sort(byDateDesc);

  const tilPosts = tilDocs
    .filter((doc) => (doc.frontmatter.status || "published") === "published")
    .map((doc) => toPost(doc, "articles", ["til"]))
    .sort(byDateDesc);

  const thoughts = thoughtDocs
    .filter((doc) => (doc.frontmatter.status || "published") === "published")
    .map(toThought)
    .sort((a, b) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      return byDateDesc(a, b);
    });

  const posts = [...articles, ...projects, ...tilPosts].sort(byDateDesc);
  const tagSet = new Set();
  for (const post of posts) {
    for (const tag of post.tags) tagSet.add(tag);
  }

  const manifest = {
    posts,
    thoughts,
    tags: [...tagSet].sort((a, b) => a.localeCompare(b)),
    articles: [...articles, ...tilPosts].sort(byDateDesc),
    projects,
  };

  await fs.mkdir(generatedDir, { recursive: true });
  await fs.writeFile(outputPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
  console.log(`Wrote ${outputPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
