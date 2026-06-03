import MarkdownIt from "markdown-it";
import MarkdownItCollapsible from "markdown-it-collapsible";

const md = new MarkdownIt({ html: true }).use(MarkdownItCollapsible);

function normalizeToken(t) {
  return {
    type: t.type,
    tag: t.tag,
    nesting: t.nesting,
    content: t.content,
    children: t.children ? t.children.map(normalizeToken) : [],
    markup: t.markup,
    info: t.info,
    attrs: t.attrs ? t.attrs.map(([k, v]) => ({ key: k, value: v })) : [],
    hidden: t.hidden,
  };
}

export const parse = (src) => md.parse(src, {}).map(normalizeToken);
