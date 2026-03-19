# Test: Animated Portfolio Website

## What it tests
- Complex animations (framer-motion or CSS)
- Multi-section single page
- Contact form
- Image handling
- Responsive design
- Performance with animations

## Prompt
```
Build a stunning developer portfolio website with these sections:

1. **Hero** - Full viewport with animated gradient background, name in large typography with a typing effect, tagline, and scroll-down indicator with bounce animation
2. **About** - Split layout: photo placeholder on left, bio text on right with skill bars that animate when scrolled into view. Skills: React (90%), TypeScript (85%), Node.js (80%), Python (75%), Docker (70%)
3. **Projects** - Grid of 6 project cards with hover effects (scale up, show overlay with description). Each card has: screenshot placeholder, title, tech stack tags, GitHub and live demo links. Filter by tech stack.
4. **Experience** - Vertical timeline with alternating sides. 4 entries with company, role, dates, and bullet points. Lines animate as you scroll.
5. **Blog** - 3 latest blog post cards with date, read time, tags, and excerpt
6. **Contact** - Contact form (name, email, subject, message) with validation and success animation. Social links row (GitHub, LinkedIn, Twitter, Email) with hover effects.

Use smooth scroll navigation. Add a scroll progress bar at top. Navbar becomes sticky and changes background after scrolling past hero. All sections animate in on scroll (fade up). Use a modern color palette with an accent color throughout. Mobile responsive with hamburger menu.
```

## Expected behavior
- Scroll-triggered animations
- Multiple section components
- CSS animations or framer-motion
- Form validation
- Responsive navbar with hamburger
- Intersection observer usage
- Consistent design system
