#!/usr/bin/env python3
"""Validate the Miso skill suite; optionally compare live documentation routes.

Standard library only. Read-only: never overwrites the curated manifest.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urldefrag, urljoin, urlparse
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "miso-thinking/references/docs-routes.json"
ORIGIN = "https://haskell-miso.org"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []
        self.has_heading = False

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.hrefs.append(dict(attrs).get("href", ""))
        elif tag == "h1":
            self.has_heading = True


def fetch(url):
    request = Request(url, headers={"User-Agent": "miso-skills-docs-check/1.0"})
    with urlopen(request, timeout=30) as response:
        return response.read(), response.url, response.status


def doc_url(base, href):
    parsed = urlparse(urljoin(base, href))
    if (
        parsed.scheme == "https"
        and parsed.netloc == "haskell-miso.org"
        and parsed.path.startswith("/docs/")
        and not parsed.query
    ):
        return ORIGIN + parsed.path
    return None


def check_local(manifest):
    errors = []
    skills = {p.parent.name: p for p in ROOT.glob("miso-*/SKILL.md")}
    for name, path in skills.items():
        content = path.read_text()
        match = re.match(r"\A---\n(.*?)\n---\n", content, re.S)
        if not match:
            errors.append(f"Missing frontmatter: {path}")
            continue
        # These skills deliberately use simple, single-line YAML scalars.
        fields = dict(line.split(": ", 1) for line in match[1].splitlines() if ": " in line)
        if fields.get("name") != name or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) or len(name) > 64:
            errors.append(f"Invalid skill name: {path}")
        if not 1 <= len(fields.get("description", "")) <= 1024:
            errors.append(f"Invalid description: {path}")
        if len(content.splitlines()) >= 500:
            errors.append(f"Skill needs progressive disclosure: {path}")

    for path in ROOT.rglob("*.md"):
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text()):
            target = urldefrag(target.strip("<>"))[0]
            if not target or urlparse(target).scheme:
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.is_relative_to(ROOT) or not resolved.exists():
                errors.append(f"Missing or out-of-suite link: {path.relative_to(ROOT)} -> {target}")

    routes = manifest["routes"]
    urls = [r["url"] for r in routes]
    if len(urls) != len(set(urls)):
        errors.append("Duplicate manifest URLs")
    route_paths = [r["route"] for r in routes]
    if len(route_paths) != len(set(route_paths)):
        errors.append("Duplicate manifest paths")
    mapped = (ROOT / "miso-thinking/references/docs-map.md").read_text()
    for route in routes:
        if route["url"] != ORIGIN + route["route"] or not route["route"].startswith("/docs/"):
            errors.append(f"Invalid route: {route['route']}")
        if route["skill"] not in skills:
            errors.append(f"Unknown skill owner: {route['skill']}")
        reference = ROOT / route["reference"]
        if not reference.is_file() or not route["reference"].startswith(route["skill"] + "/references/"):
            errors.append(f"Missing or mismatched reference: {route['reference']}")
        if f"({route['url']})" not in mapped or f"`{route['route']}`" not in mapped:
            errors.append(f"Missing human-readable route: {route['url']}")
        if not route["summary"] or route["http_status"] != 200:
            errors.append(f"Incomplete route record: {route['route']}")
    unowned = set(skills) - {r["skill"] for r in routes}
    if unowned:
        errors.append(f"Skills without mapped sources: {sorted(unowned)}")
    return errors, len(skills), len(routes)


def check_online(manifest):
    errors = []
    sitemap, _, _ = fetch(manifest["source"])
    discovered = set()
    for element in ET.fromstring(sitemap).iter():
        if element.tag.rsplit("}", 1)[-1] == "loc" and element.text:
            url = doc_url(ORIGIN, element.text)
            if url:
                discovered.add(url)
    expected = {r["url"] for r in manifest["routes"]}
    pending = discovered | expected
    visited = set()

    def inspect(url):
        try:
            raw, final, status = fetch(url)
            if status != 200 or not doc_url(ORIGIN, final):
                return url, [], f"Unexpected response: {url} -> {status} {final}"
            parser = Links()
            parser.feed(raw.decode("utf-8"))
            if not parser.has_heading:
                return url, [], f"No page heading (possible non-content response): {url}"
            links = [doc_url(final, href) for href in parser.hrefs]
            return url, [link for link in links if link], None
        except Exception as exc:
            return url, [], f"Fetch failed: {url}: {exc}"

    while pending - visited:
        batch = sorted(pending - visited)
        with ThreadPoolExecutor(max_workers=6) as pool:
            for url, links, error in pool.map(inspect, batch):
                visited.add(url)
                if error:
                    errors.append(error)
                discovered.update(links)
                pending.update(links)
        if len(pending) > 1000:
            errors.append("Discovery exceeded 1000 URLs; review documentation scope")
            break
    for url in sorted(discovered - expected):
        errors.append(f"Unmapped live route: {url}")
    for url in sorted(expected - discovered):
        errors.append(f"Mapped route no longer discoverable: {url}")
    return errors, len(visited)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--online", action="store_true", help="fetch sitemap and recursively check documentation links")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    errors, skills, routes = check_local(manifest)
    print(f"Local: {skills} skills, {routes} routes; {len(errors)} errors")
    if args.online:
        try:
            online_errors, visited = check_online(manifest)
            errors.extend(online_errors)
            print(f"Online: {visited} URLs checked; {len(online_errors)} errors")
        except Exception as exc:
            errors.append(f"Online check failed: {exc}")
    for error in errors:
        print(f"ERROR: {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
