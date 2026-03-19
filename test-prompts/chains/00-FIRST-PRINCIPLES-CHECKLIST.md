# First Principles Checklist

Use this after EVERY message in a chain. The model should do ALL of these
without being asked. If it doesn't, that's a fail.

---

## Project Scaffolding (Message 1 of any chain)
The model should AUTOMATICALLY:

- [ ] Create a proper project directory structure (not dump everything in root)
- [ ] Create `package.json` with name, scripts, dependencies, devDependencies
- [ ] Create `tsconfig.json` if using TypeScript
- [ ] Create `vite.config.ts` if using Vite
- [ ] Create `index.html` entry point
- [ ] Set up proper folder structure (`src/`, `src/components/`, etc.)
- [ ] Install ALL dependencies in one `npm install` command
- [ ] Start the dev server as the LAST action
- [ ] Use proper file naming conventions (PascalCase components, kebab-case files)

## Code Organization (Every message)
The model should AUTOMATICALLY:

- [ ] Split components into separate files (not 500 lines in App.tsx)
- [ ] Create a `types.ts` or `types/` for shared interfaces
- [ ] Extract utilities/helpers into separate files
- [ ] Group related files in folders (components/, hooks/, utils/, etc.)
- [ ] Use proper imports between files

## Incremental Updates (Messages 2+)
The model should AUTOMATICALLY:

- [ ] Reuse the same artifact ID from previous messages
- [ ] Only include CHANGED files (not rewrite untouched files)
- [ ] Add new dependencies to existing package.json (not create new one)
- [ ] NOT restart dev server if only files changed
- [ ] Preserve user's existing code/structure

## Feature Implementation (Any feature request)
The model should AUTOMATICALLY:

- [ ] Handle loading states
- [ ] Handle error states
- [ ] Handle empty states
- [ ] Add proper TypeScript types (no `any`)
- [ ] Make it responsive without being asked
- [ ] Add keyboard support where obvious (Escape to close, Enter to submit)
- [ ] Populate with realistic mock data (not "Item 1, Item 2, Item 3")

## When Auth is Involved
The model should AUTOMATICALLY:

- [ ] Create sign up AND login pages
- [ ] Add a protected route wrapper
- [ ] Redirect unauthenticated users to login
- [ ] Create a logout button
- [ ] Set up .env file for credentials
- [ ] Create Supabase migration files
- [ ] Enable RLS on every table
- [ ] Add policies so users only see their own data

## When Database is Involved
The model should AUTOMATICALLY:

- [ ] Create migration files (not just tell the user what SQL to run)
- [ ] Use `IF NOT EXISTS` / `IF EXISTS` for safety
- [ ] Add proper foreign keys
- [ ] Add indexes on frequently queried columns
- [ ] Enable RLS
- [ ] Write RLS policies
- [ ] Create a Supabase client singleton

---

## Grading

For each message in a chain, count how many applicable items the model
handled WITHOUT being prompted:

- **A (90%+):** Production-ready first-principles thinking
- **B (70-89%):** Good but missed some obvious stuff
- **C (50-69%):** Needs hand-holding on basics
- **D (30-49%):** Barely scaffolds, dumps code
- **F (<30%):** Just answers the question without building anything

Track scores across models to compare:
| Model | Chain | Msg | Score | Notes |
|-------|-------|-----|-------|-------|
|       |       |     |       |       |
