# OSA Terminal Test Prompts

## How to use

Each chain simulates a REAL user session: start simple, build up, iterate.
Send messages one at a time, wait for response, check the results, then send the next.

**After every message, grade using `chains/00-FIRST-PRINCIPLES-CHECKLIST.md`**

## Chains (main tests - use these)

| # | Chain | Messages | Tests |
|---|-------|----------|-------|
| 01 | Kanban Board | 6 | Scaffolding, drag-drop, persistence, bug fixes |
| 02 | E-Commerce Dashboard | 7 | Routing, charts, tables, modals, responsive |
| 03 | Chat App | 6 | Complex state, multi-panel, emoji, threads |
| 04 | Portfolio Site | 5 | Scroll animations, Intersection Observer, forms |
| 05 | Todo + Supabase | 6 | Auth, migrations, RLS, CRUD, tags |
| 06 | Bugfix Chain | 5 | Debug skills, targeted fixes, teaching |
| 07 | Mobile Finance App | 5 | Expo, React Native, charts, navigation |
| 08 | SaaS Landing Page | 4 | Pure design quality, responsive, CSS polish |

## Quick start

1. Pick a chain (start with 06 or 08 for fastest feedback)
2. Open OSA terminal
3. Send Message 1 from the chain file
4. Wait for full response
5. Check the "First Principles Check" items
6. Score it (A/B/C/D/F)
7. Send Message 2
8. Repeat

## What we're testing

The prompts are DELIBERATELY VAGUE about setup. The model should:
- Choose the right tech stack without being told
- Scaffold a proper project directory
- Create package.json, tsconfig, configs
- Split code into components/modules
- Add proper types
- Handle edge cases
- Make things responsive
- Generate realistic mock data

If the model needs to be told ANY of this, that's a fail.

## Scoring

Track in the scoring table at the bottom of each chain file.
Compare across models to find which ones have real first-principles thinking.

## Old single-prompt tests

The `tier1-basic/` through `tier4-edge/` folders have standalone prompts.
Use those for quick one-shot tests. The chains are the real evaluation.
