# Chain 01: Kanban Board (6 messages)

Tests: artifact generation, incremental updates, drag-drop, state management, persistence

**KEY: None of these prompts tell the model HOW to scaffold. It must figure that out.**

---

## Message 1 — Foundation
```
Build me a kanban board. 3 columns: To Do, In Progress, Done. I need to be able to add cards to any column. Dark theme.
```

**First Principles Check (see 00-CHECKLIST):**
- Did it choose React + TypeScript on its own?
- Did it create package.json with vite, react, react-dom, typescript?
- Did it create tsconfig.json?
- Did it set up src/ folder with components/?
- Did it create separate Column and Card components (not everything in App.tsx)?
- Did it create a types.ts with Card/Column interfaces?
- Did it run npm install?
- Did it start the dev server?
- Did it add any CSS reset or base styles?
- Did it generate realistic placeholder cards or leave columns empty?

**Wait for response, verify it runs, then send:**

---

## Message 2 — Expand the cards
```
Cards need more info. Add description, priority (low/medium/high) with color coding, and due date. Show priority as a colored left border on each card.
```

**First Principles Check:**
- Did it update the Card type/interface to include new fields?
- Did it update the "add card" form to include new fields?
- Did it add form validation (title required at minimum)?
- Did it keep existing components intact?
- Did it reuse the artifact ID?
- Did it NOT restart the dev server?

---

## Message 3 — Drag and drop
```
Add drag and drop so I can move cards between columns and reorder within a column.
```

**First Principles Check:**
- Did it pick a drag library (react-beautiful-dnd, @hello-pangea/dnd, dnd-kit)?
- Did it add the dependency to package.json?
- Did it run npm install for the new dep?
- Did it add proper drag handles / visual feedback?
- Did it update state correctly on drop?
- Did it handle the edge case of dropping on same position?

---

## Message 4 — Persistence + search
```
Save everything so it persists on refresh. Also add search that filters cards across all columns.
```

**First Principles Check:**
- Did it know "persists on refresh" means localStorage?
- Did it create a custom hook (useLocalStorage) or inline it?
- Did it handle initial load from localStorage?
- Did it debounce the search input?
- Does search highlight matches or just filter?
- Does clearing search restore all cards?

---

## Message 5 — Bug report
```
When I drag a card to a new column the card count in the column header doesn't update. Also search should clear when I press Escape.
```

**First Principles Check:**
- Did it fix ONLY the bugs without rewriting unrelated code?
- Did it identify the root cause (state not updating count) vs just patching?
- Did it add the Escape key handler?
- Did it add an X button to clear search too (common UX pattern)?

---

## Message 6 — New feature on top
```
Let me create new columns and delete columns. When deleting, move its cards to the first column. Add a "Clear Done" button too.
```

**First Principles Check:**
- Did it add a confirmation dialog for destructive actions (delete column, clear done)?
- Did it handle the edge case of deleting the last column?
- Did it prevent deleting a column if it's the only one?
- Did it add the "add column" UI intuitively (+ button in header)?
- Did it update localStorage to persist new columns?

---

## Scoring Summary
| Message | Score | Notes |
|---------|-------|-------|
| 1       |       |       |
| 2       |       |       |
| 3       |       |       |
| 4       |       |       |
| 5       |       |       |
| 6       |       |       |
| **Avg** |       |       |
