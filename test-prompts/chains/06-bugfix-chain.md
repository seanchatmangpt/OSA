# Chain 06: Debug & Fix Chain (5 messages)

Tests: understanding broken code, targeted fixes, not over-rewriting, teaching

**KEY: Tests if the model can be surgical instead of rewriting from scratch.**

---

## Message 1 — Paste broken code
```
This React app has bugs. Fix them but keep the same structure:

import { useState } from 'react';

function App() {
  const [count, setCount] = useState(0);
  const [theme, setTheme] = useState('light');

  const increment = () => setCount(count + 1);
  const decrement = () => setCount(count - 1);
  const reset = () => count = 0;

  const toggleTheme = () => {
    setTheme(theme === 'light' ? 'dark' : 'light');
    document.body.className = theme;
  };

  return (
    <div className={`app ${theme}`}>
      <h1>Counter: {count}</h1>
      <button onClick={increment}>+</button>
      <button onClick={decrement}>-</button>
      <button onClick={reset}>Reset</button>
      <button onClick={toggleTheme}>
        {theme === 'light' ? 'Dark' : 'Light'} Mode
      </button>
    </div>
  );
}

export default App;
```

**First Principles Check:**
- Did it identify ALL 3 bugs?
  1. No guard on decrement (goes negative)
  2. reset mutates state directly (`count = 0` instead of `setCount(0)`)
  3. toggleTheme uses stale `theme` for className (sets OLD value)
- Did it explain each bug clearly?
- Did it set up a project to run this (package.json, vite, etc.)?
- Did it add basic CSS so the theme toggle is visible?
- Did it NOT rewrite the whole thing into a different pattern?
- Did it keep the same component structure?

---

## Message 2 — Add feature on fixed code
```
Add a step size input so I can increment/decrement by custom amounts.
```

**First Principles Check:**
- Did it add a number input with proper min value?
- Did it default step to 1?
- Did it update increment/decrement to use the step?
- Did it handle invalid input (empty, negative, 0)?
- Did it show the current step somewhere visible?
- Did it keep all previous bug fixes intact?

---

## Message 3 — Subtle bug report
```
The theme toggle still feels off. When I click it the first time nothing changes visually. What's going on?
```

**First Principles Check:**
- Did it recognize this is the stale closure issue in toggleTheme?
- `document.body.className = theme` sets the OLD value because setState hasn't run yet
- Did it fix it properly? (use the NEW value, or useEffect)
- Did it explain WHY this happens (React batching, stale closure)?
- Did it NOT add unrelated changes?

---

## Message 4 — Different broken code
```
New code, different bugs. This todo list is broken:

const [todos, setTodos] = useState([]);

const addTodo = (text) => {
  todos.push({ id: Date.now(), text, done: false });
  setTodos(todos);
};

const deleteTodo = (id) => {
  const filtered = todos.filter(t => t.id !== id);
  setTodos(todos);
};

const toggleDone = (id) => {
  const todo = todos.find(t => t.id === id);
  todo.done = !todo.done;
  setTodos(todos);
};
```

**First Principles Check:**
- Did it identify ALL 3 mutation bugs?
  1. addTodo: push mutates array, setTodos(todos) passes same reference
  2. deleteTodo: filters correctly but passes `todos` instead of `filtered`
  3. toggleDone: directly mutates the todo object
- Did it explain that React needs NEW references to trigger re-render?
- Did it fix with spread operators / map?
- Did it NOT change the function signatures?

---

## Message 5 — Teach the pattern
```
Why does this keep happening? What's the rule I should always follow?
```

**First Principles Check:**
- Did it explain React's immutability requirement clearly?
- Did it give the general rules:
  1. Never mutate state directly
  2. Always create new arrays/objects
  3. Use spread, map, filter to create copies
- Did it give concrete before/after examples?
- Was the explanation appropriate for the skill level shown?
- Did it NOT just dump a wall of text?

---

## Scoring Summary
| Message | Score | Notes |
|---------|-------|-------|
| 1       |       |       |
| 2       |       |       |
| 3       |       |       |
| 4       |       |       |
| 5       |       |       |
| **Avg** |       |       |
