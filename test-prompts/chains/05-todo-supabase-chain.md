# Chain 05: Full-Stack Todo with Supabase (6 messages)

Tests: database setup, migrations, auth, RLS, CRUD, complex queries

**KEY: User just says "with a database" - model must know to use Supabase, set up migrations, RLS, etc.**

---

## Message 1 — Auth
```
Build a todo app with user accounts. I need signup, login, and a protected dashboard. If I'm not logged in, send me to login.
```

**First Principles Check:**
- Did it choose Supabase for auth (per system prompt defaults)?
- Did it create signup AND login pages?
- Did it create a ProtectedRoute/AuthGuard wrapper?
- Did it create a Supabase client singleton?
- Did it create a .env file with placeholder Supabase vars?
- Did it remind user to connect Supabase (if not connected)?
- Did it use email/password auth (not magic links)?
- Did it add a logout button?
- Did it set up proper routing (login, signup, dashboard)?
- Did it handle loading state while checking auth?

---

## Message 2 — Todos CRUD
```
Now add todos. I need title, description, priority 1-5, and due date. Let me check them off and see all my todos in a list.
```

**First Principles Check:**
- Did it create a Supabase migration file for the todos table?
- Did the migration include RLS enabled + policies?
- Did it create BOTH migration file AND query execution actions?
- Did it add user_id foreign key to auth.users?
- Did it create an "add todo" form with all fields?
- Did it add form validation (title required)?
- Did it show priority visually (color, number, stars)?
- Did it format due dates nicely?
- Did it show overdue todos differently?

---

## Message 3 — Filtering and sorting
```
I need to filter: all, active, completed, and overdue. And sort by date, priority, or due date.
```

**First Principles Check:**
- Did it add filter buttons/tabs (not dropdown)?
- Did it add a sort dropdown?
- Do filters and sort work TOGETHER?
- Did it show result count ("12 todos" / "3 active")?
- Does "overdue" correctly check due_date < now AND !completed?
- Did it do filtering on the client or make new Supabase queries?
- Did the URL update to reflect filters (optional but good)?

---

## Message 4 — Tags
```
Add tags. I want to create my own tags with colors and assign multiple tags to each todo.
```

**First Principles Check:**
- Did it create a NEW migration file (not edit the old one)?
- Did it create a tags table AND a todo_tags junction table?
- Did it add RLS on BOTH new tables?
- Did the junction table have proper foreign keys?
- Did it create a tag management UI (create tags with color picker)?
- Did it add tag assignment to the todo form?
- Did it show tags as colored pills on each todo?
- Did it add a tag filter?

---

## Message 5 — Inline editing + delete
```
Let me edit todos inline. Click the title to edit it right there. Add delete with confirmation. And a "Clear Completed" button.
```

**First Principles Check:**
- Did it implement click-to-edit (not a separate edit page)?
- Did it save on blur or Enter?
- Did it handle Escape to cancel editing?
- Did it add a confirmation dialog for delete (not window.confirm)?
- Did "Clear Completed" have its own confirmation?
- Did it handle the case where there are no completed todos?
- Did it update Supabase on every inline edit?

---

## Message 6 — Dashboard stats
```
Add some stats at the top: total todos, completed today, overdue, and completion rate. Show a chart of completions this week. Add dark/light theme toggle.
```

**First Principles Check:**
- Did it calculate stats from actual data (not hardcoded)?
- Did it add a completion percentage ring/circle?
- Did it add a chart (bar or line) for weekly completions?
- Did it create a theme toggle that persists (localStorage)?
- Did the dark/light theme apply to ALL components?
- Did it create proper CSS variables or a theme system?
- Did it handle the chart colors in both themes?

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
