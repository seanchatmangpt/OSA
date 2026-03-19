# Test: Full-Stack Todo with Supabase

## What it tests
- Supabase integration
- Database migrations with RLS
- Authentication (email/password)
- CRUD operations
- TypeScript types from schema
- Environment variables

## Prompt
```
Build a full-stack todo application with user authentication using Supabase. Requirements:

- Email/password authentication with sign up and login pages
- Protected routes - redirect to login if not authenticated
- Todo CRUD:
  - Create todos with title, description, priority (1-5), and due date
  - Mark as complete/incomplete
  - Edit inline
  - Delete with confirmation
  - Filter by: all, active, completed, overdue
  - Sort by: date created, due date, priority
- Categories/tags - users can create tags and assign multiple to each todo
- Dashboard showing: total todos, completed today, overdue count, completion rate chart
- Dark/light theme toggle that persists
- Fully responsive

Create proper Supabase migrations with RLS policies so users can only see their own todos.
```

## Expected behavior
- Supabase migration files with RLS
- Auth flow (signup, login, logout)
- Protected route wrapper
- Multiple tables (todos, tags, todo_tags)
- Environment variables setup
- Complex queries with filters/sorts
