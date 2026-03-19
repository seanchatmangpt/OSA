# Test: Ambiguous/Challenging Requests

## What it tests
- How the model handles vague requirements
- Whether it asks clarifying questions vs makes assumptions
- Code quality under pressure
- Handling impossible constraints gracefully

## Prompts (test each independently):

### Vague request:
```
Make me an app
```

### Contradictory requirements:
```
Build a real-time multiplayer game that works offline with no server and syncs data between players instantly
```

### Extremely long single prompt:
```
Build a complete project management tool like Jira with the following features: user authentication with role-based access control (admin, project manager, developer, viewer), project creation and management, sprint planning with drag-and-drop, backlog management, kanban board view, list view, timeline/gantt chart view, story points estimation, velocity tracking charts, burndown charts, sprint retrospective notes, team management with capacity planning, custom workflows per project, email notifications on assignment changes, activity feed showing all project changes, advanced search with JQL-like query language, keyboard shortcuts for common actions, bulk operations on issues, custom fields per project, file attachments on issues, issue linking and dependencies, sub-tasks, epic grouping, release management, time tracking per issue, reports dashboard with exportable charts, and a settings page for user preferences. Use React, TypeScript, and Supabase. Make it production-ready.
```

## Expected behavior
- "Make me an app" → should ask what kind or make reasonable assumptions
- Contradictory → should explain constraints and suggest alternatives
- Mega prompt → should handle gracefully, may simplify scope but should attempt it
