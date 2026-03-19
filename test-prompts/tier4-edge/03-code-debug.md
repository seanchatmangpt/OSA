# Test: Debug Existing Code

## What it tests
- Understanding existing code pasted by user
- Finding and fixing bugs
- Explaining issues clearly
- Not rewriting everything from scratch

## Prompt:
```
This React component is broken. The counter goes to negative numbers even though it shouldn't, the reset button doesn't work, and the theme toggle crashes the app. Fix the bugs:

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
      <button onClick={toggleTheme}>Toggle Theme</button>
    </div>
  );
}
```

## Expected behavior
- Identifies 3 bugs:
  1. No guard on decrement (allows negatives)
  2. reset directly mutates state instead of using setCount
  3. toggleTheme sets className to old theme value (stale closure)
- Fixes each bug specifically
- Doesn't rewrite the whole app unnecessarily
