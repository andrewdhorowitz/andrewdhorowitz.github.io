# andrewdhorowitz.github.io

[![CI](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/ci.yml) [![Lighthouse](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/lighthouse.yml/badge.svg)](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/lighthouse.yml) [![Links](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/links.yml/badge.svg)](https://github.com/andrewdhorowitz/andrewdhorowitz.github.io/actions/workflows/links.yml)

Personal portfolio site (andrewdhorowitz.com): an open portfolio with tabs for Projects, Automations, The Playbook, and Get in touch — featuring Routines & Streaks, the AIMF Protocol, and Family Cards, plus the home automations that run the day, all built spec-first with AI assistance.

> **Published:** Site — https://andrewdhorowitz.com/ · Docs — https://andrewdhorowitz.com/docs/whole-system-architecture.md · Interactive — https://andrewdhorowitz.com/docs/interactive-architecture.html · Repo — https://github.com/andrewdhorowitz/andrewdhorowitz.github.io

Live at https://andrewdhorowitz.com/ (Cloudflare Pages; GitHub Pages mirror at https://andrewdhorowitz.github.io/)

Contact: hello@andrewdhorowitz.com

Discovery: canonical link + Open Graph tags in the head (og-image.png is the social card, favicon.svg the tab icon); robots.txt and sitemap.xml sit at the root.
Translation: a GTranslate free widget in the header band auto-detects the visitor's browser language and translates the page in place (prompts are not translated).

Architecture: C4-lite diagrams for the site itself live in [docs/architecture.md](docs/architecture.md), and the whole-system context diagram in [docs/whole-system-architecture.md](docs/whole-system-architecture.md); the page renders both from those canonical sources.

Plain static HTML, no build step. Edit `index.html` and push; Cloudflare Pages serves the custom domain and GitHub Pages serves the mirror.
