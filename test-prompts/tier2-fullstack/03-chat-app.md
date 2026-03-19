# Test: Real-time Chat Application

## What it tests
- WebSocket or polling simulation
- Multiple views/screens
- User state management
- Message threading
- File structure organization

## Prompt
```
Build a Slack-like chat application using React and TypeScript. Features:

- Left sidebar with channels list (#general, #random, #dev, #design) and direct messages
- Channel creation with name and description
- Message input with support for:
  - Text messages with markdown formatting
  - Emoji picker
  - File attachment indicator (mock, no actual upload needed)
- Message display with:
  - User avatar and name
  - Timestamp
  - Message reactions (click to add emoji reactions)
  - Thread replies (click to open thread in side panel)
- Unread message indicators on channels
- Online/offline user status dots
- User profile popup on avatar click
- Search messages across all channels
- Responsive: full layout on desktop, tab-based on mobile

Populate with 4 mock users and 20+ messages across channels. Use a dark theme similar to Discord/Slack dark mode.
```

## Expected behavior
- Complex component hierarchy
- State management for messages, channels, users
- Side panel for threads
- Emoji picker component
- Dark theme throughout
- Mock data for users and messages
