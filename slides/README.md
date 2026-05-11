# Reveal.js Slides Baseline

This repository uses a Reveal.js + custom themes baseline for presentations.

## Structure
- `slides/template.html`: starter template with placeholders
- `slides/themes/default/theme.css`: default visual theme
- `slides/themes/contrast/theme.css`: high-contrast alternative
- `slides/decks/`: generated decks
- `slides/new-deck.sh`: scaffold helper

## Create a deck

```bash
bash slides/new-deck.sh roadmap default
```

This creates `slides/decks/roadmap.html` based on `slides/template.html` and selected theme.

## Run locally

Open the generated HTML file directly, or serve the repository root with any static file server.
