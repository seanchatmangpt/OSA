# Chain 04: Portfolio Website (5 messages)

Tests: animations, scroll effects, responsive design, forms, visual polish

**KEY: No mention of frameworks, tools, or file structure. Model must decide everything.**

---

## Message 1 — Hero section
```
Build a portfolio site for a developer named Alex Rivera. Start with a hero that fills the screen - big name, a typing effect that cycles through job titles, animated gradient background, and a scroll-down arrow that bounces.
```

**First Principles Check:**
- Did it choose an appropriate tech stack (React/Vite or even vanilla)?
- Did the typing effect actually cycle through multiple strings?
- Did the gradient animate (not static)?
- Is the scroll arrow actually bouncing (CSS animation)?
- Did it set up proper project scaffolding?
- Did it add a CSS reset / normalize?
- Did it set up proper font (Google Fonts import)?
- Is the hero actually 100vh?

---

## Message 2 — About + Skills
```
Add an About section. Photo on the left, bio on the right, then skill bars that animate when you scroll to them. React 90%, TypeScript 85%, Node.js 80%, Python 75%, AWS 70%.
```

**First Principles Check:**
- Did it use a stock photo from Pexels (per system prompt)?
- Did it implement Intersection Observer for scroll animation?
- Do skill bars actually animate from 0% to their value?
- Did it only animate ONCE (not re-animate every scroll)?
- Is the layout responsive (stacks on mobile)?
- Did it show percentages on/next to the bars?
- Did it add proper section padding/spacing?

---

## Message 3 — Projects grid
```
Add a Projects section. 6 project cards in a grid. Each has a title, description, tech tags, and GitHub/demo links. Cards should have a hover effect. Let me filter by tech.
```

**First Principles Check:**
- Did it create 6 realistic project entries (not "Project 1")?
- Did it add realistic tech stack tags (React, Node, Python, etc.)?
- Did hover effect include transform + shadow?
- Did it add filter buttons (All, Frontend, Backend, etc.)?
- Does the filter actually work?
- Did it animate cards when filtering (fade in/out)?
- Did it create a ProjectCard component (reusable)?
- Did it add proper link icons for GitHub / external link?

---

## Message 4 — Navigation + scroll behavior
```
Add a sticky nav bar with links to each section. It should be transparent over the hero and get a solid background after scrolling. Add a scroll progress bar at the top. Highlight which section I'm currently viewing.
```

**First Principles Check:**
- Did it implement scroll event listener for navbar background?
- Did it implement smooth scroll on nav link click?
- Is the progress bar functional (grows as you scroll)?
- Does the active section highlight update on scroll?
- Did it use Intersection Observer for active section detection?
- Did it add a hamburger menu for mobile?
- Does the nav have a proper z-index (always on top)?

---

## Message 5 — Contact + responsive
```
Add a contact form at the bottom with validation, social links, and a footer. Make the whole page work on mobile.
```

**First Principles Check:**
- Did it add name, email, subject, message fields?
- Did it validate email format?
- Did it show inline error messages (not alert)?
- Did it add a success state after "submit"?
- Did it add social icons (GitHub, LinkedIn, Twitter, Email)?
- Did social icons have hover effects?
- Did it add a copyright footer?
- RESPONSIVE: Does the 3-column project grid become 2 then 1?
- RESPONSIVE: Does About section stack vertically?
- RESPONSIVE: Does the hamburger menu actually work?
- RESPONSIVE: Is text still readable on mobile?

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
