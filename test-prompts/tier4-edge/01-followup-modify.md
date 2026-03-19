# Test: Follow-up Modification Chain

## What it tests
- Context retention across messages
- Incremental updates to existing artifacts
- Correct file modification (not rewrite from scratch)
- Handling user feedback

## Prompt Sequence

### Message 1:
```
Build a simple React counter app with increment, decrement, and reset buttons. Use TypeScript and style it nicely.
```

### Message 2 (after response):
```
Add a history panel on the right side that shows every action taken (increment, decrement, reset) with timestamps. Also add an undo button that reverts the last action.
```

### Message 3 (after response):
```
Now make it so I can set a custom step size (how much to increment/decrement by). Add a number input for the step size. Also change the color scheme to use blue instead of whatever you picked.
```

### Message 4 (after response):
```
There's a bug - when I undo a reset, it should go back to the value before the reset, not just subtract the step. Fix that.
```

## Expected behavior
- Each response builds on the previous
- Files are updated, not duplicated
- Artifact IDs are reused
- Bug fix is targeted, not a full rewrite
