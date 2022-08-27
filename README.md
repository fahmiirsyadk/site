<h1 align="center">site</h1>
<p align="center">
Personal website to unify my fragmented thoughts
</p>

<br>

<p align="center">
  <img src="./src/public/assets/images/logo.svg" alt="logo" />
</p>
<p align="center">built with dust</p>

<br>

### Architecture of this site
- [Melange](https://github.com/melange-re/melange)
used to transpile OCaml syntax to JS
- [Esy](https://esy.sh/en/) package management for native Reason, OCaml and more
- [TailwindCSS](https://tailwindcss.com/) you already know this XD

and etc, mostly used to run the static site generator engine.

### Folder structures

- **.github/workflows** -- run action to compile the site
- **generator/** -- the SSG engine
- **src/** -- all website code goes there
- **tailwindcss/** -- tailwindcss declaration

### How to run it ?
it's pretty complicated, you need open 3 terminal window

#### [ 01 ] **Installation**
1. Installing NodeJS packages
```bash
yarn # or npm install
```
2. Installing Melange, OCaml packages using esy
```bash
yarn build # or npm run build
```

#### [ 02 ] **Running**
1. On first window, we need to run melange
```sh
yarn watch # or npm run watch
```
2. On second window, run the SSG
```sh
yarn dust:dev # or npm run dust:dev
```
3. Last window, running tailwindcss watcher to detect css changes
```sh
yarn css:dev # or npm run css:dev
```
4. Open **localhost:8080**

<br>
<hr>

### Need improvements
- [ ] Access another page without reload the page
- [ ] Markdown need TOC support
- [ ] Migrate Rescript Syntax to OCaml
- [ ] Simplify import script
- [ ] Add Darkmode
- [ ] Add AlpineJS (?)
- [ ] Add feature to store assets on individual post page
```bash
# Idea
some-article/
-- index.md
-- assets/*
```
- [ ] Rewrite engine flow
