# Images Directory

This directory contains static image assets for markdown content.

## Structure

Images are organized by article/project slug. For example, images for the `deconstruct-site` article should be placed in:

```
public/assets/images/deconstruct-site/
```

## Usage in Markdown

In your markdown files, reference images using absolute paths:

```markdown
<img src="/assets/images/deconstruct-site/terminal-1.gif" alt="Description">
```

or

```markdown
![Description](/assets/images/deconstruct-site/image.jpg)
```

## How it works

- Files in the `public/` directory are served at the root URL path
- `/assets/images/article-slug/image.png` → `public/assets/images/article-slug/image.png`
- Images are copied to the build output during the build process
