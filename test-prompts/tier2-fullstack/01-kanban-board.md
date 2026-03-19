# Test: Kanban Board App

## What it tests
- React project setup (Vite + React + TypeScript)
- Multiple components across files
- Drag and drop
- State management
- localStorage persistence
- Complex UI interactions

## Prompt
```
Build a Kanban board app using React and TypeScript. Features:
- 4 default columns: Backlog, To Do, In Progress, Done
- Add/edit/delete cards with title, description, priority (low/medium/high), and due date
- Drag and drop cards between columns and reorder within columns
- Color-coded priority indicators
- Search/filter cards by text or priority
- Persist everything to localStorage
- Add new columns
- Card count per column
- Smooth animations on drag
- Clean, modern UI with subtle shadows and rounded corners
```

## Expected behavior
- Creates 5+ component files
- Uses react-beautiful-dnd or similar
- TypeScript interfaces for Card, Column types
- localStorage read/write
- Multiple CSS/styled components
- Working drag and drop
