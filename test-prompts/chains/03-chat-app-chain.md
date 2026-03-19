# Chain 03: Chat Application (6 messages)

Tests: complex state, multi-panel layout, message rendering, emoji, threads

**KEY: Prompts don't specify React, TypeScript, or any setup details.**

---

## Message 1 — Basic layout
```
Build me a chat app like Slack. Channel list on the left, messages in the middle. Start with #general, #random, and #dev channels. Dark theme like Discord.
```

**First Principles Check:**
- Did it choose React + TypeScript on its own?
- Did it set up a proper project structure?
- Did it create Layout, Sidebar, ChannelList, MessageArea components?
- Did it create types for Channel, Message, User?
- Did it set up state management (context, zustand, or useState)?
- Did it highlight the selected channel?
- Did it pre-populate channels with mock messages (not empty)?
- Is the dark theme actually dark (proper background, text, borders)?

---

## Message 2 — Messaging
```
Let me type and send messages. Show them with a name, avatar, and timestamp. Pre-fill some conversations so it looks real.
```

**First Principles Check:**
- Did it create a MessageInput component with Enter to send?
- Did it show user avatar as colored circle with initials?
- Did it format timestamps nicely ("2:34 PM" not ISO string)?
- Did it group consecutive messages from same user?
- Did it auto-scroll to bottom on new message?
- Did mock conversations sound realistic (not "Hello", "Hi", "How are you")?
- Did it generate 4+ mock users with real names?

---

## Message 3 — Rich message display
```
Messages between different users should have different colored avatars. Show the date separator when messages are from different days. Group messages from the same user that are close together.
```

**First Principles Check:**
- Did it assign consistent colors per user (same user = same color)?
- Did it add "Today", "Yesterday", "March 14" date separators?
- Did grouped messages hide avatar/name for consecutive msgs?
- Did it add proper spacing between message groups?
- Did it keep the dark theme consistent?

---

## Message 4 — Reactions
```
When I hover a message show a little toolbar. Let me react with emoji. Show reactions below the message with counts.
```

**First Principles Check:**
- Did it create a hover toolbar (not right-click menu)?
- Did it include common emoji (thumbs up, heart, laugh, fire)?
- Did reactions show as pills below the message?
- Can clicking an existing reaction increment its count?
- Can clicking your own reaction remove it?
- Did the toolbar position correctly (not clipped at edges)?
- Did it add some pre-existing reactions on mock messages?

---

## Message 5 — Threads
```
Add a reply button on the hover toolbar. Clicking it opens a thread panel on the right with the original message and its replies.
```

**First Principles Check:**
- Did it create a third panel (sidebar | messages | thread)?
- Did it show reply count on messages that have threads?
- Did clicking a threaded message open its thread?
- Did it add a close button on the thread panel?
- Did it handle the layout (3 columns on desktop)?
- Did it add some mock thread replies?
- Can you send a new reply in the thread?

---

## Message 6 — Channel management + polish
```
Let me create new channels. Show unread indicators on channels. Add a typing indicator and an emoji picker in the message input.
```

**First Principles Check:**
- Did it add a "+" button for creating channels?
- Did it add a modal/popover for channel name input?
- Did unread indicators show as bold text + badge/dot?
- Does switching to a channel clear its unread count?
- Did it add a smiley icon that opens an emoji picker?
- Is the emoji picker an actual grid of emoji (not just 5)?
- Did it add a random "typing..." indicator for mock users?
- Did it handle all the new UI without breaking existing layout?

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
