# Test: Live Markdown Previewer

## What it tests
- npm dependency installation (marked, highlight.js)
- Split-pane layout
- Real-time updates
- Code syntax highlighting

## Prompt
```
Create a live markdown editor with a split view - editor on the left, preview on the right. Support full GitHub-flavored markdown including code blocks with syntax highlighting, tables, task lists, and images. Add a toolbar with buttons for bold, italic, headings, links, code blocks, and lists. Include a word count and reading time estimate at the bottom. Use a clean, minimal design with light/dark theme toggle.
```

## Expected behavior
- Installs marked + highlight.js (or similar)
- Split pane with live preview
- Toolbar with formatting buttons
- Theme toggle works
- Code blocks are syntax highlighted
