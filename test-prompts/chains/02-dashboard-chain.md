# Chain 02: E-Commerce Dashboard (7 messages)

Tests: routing, charts, tables, modals, responsive layout, data generation

**KEY: Prompts are intentionally vague on setup. The model must scaffold everything.**

---

## Message 1 — Skeleton
```
Build me an admin dashboard. Sidebar on the left with navigation for: Dashboard, Products, Orders, Settings. Main content area on the right. Modern look.
```

**First Principles Check:**
- Did it set up React Router without being told?
- Did it create a Layout component with sidebar + outlet?
- Did it create separate page components for each route?
- Did it add icons to the sidebar links (lucide-react, react-icons)?
- Did it highlight the active route in the sidebar?
- Did it set up proper folder structure (pages/, components/, layouts/)?
- Did it create a proper package.json, tsconfig, vite config?
- Did each page have at least a heading (not blank)?

---

## Message 2 — Dashboard page
```
Fill out the Dashboard page. I want to see revenue, orders today, average order value, and active users at the top. Then a bar chart showing this week's revenue below that.
```

**First Principles Check:**
- Did it install recharts/chart.js WITHOUT being told which library?
- Did it create realistic stat values (not $0 or "N/A")?
- Did it format currency properly ($24,500 not 24500)?
- Did it add trend indicators (up/down arrows, green/red)?
- Did it make the stat cards a reusable component?
- Did it generate realistic chart data for 7 days (Mon-Sun)?

---

## Message 3 — Products page
```
Products page needs a table. Show name, category, price, stock, and status. I need to be able to sort and search. Paginate it.
```

**First Principles Check:**
- Did it generate 20+ realistic products (not "Product 1")?
- Did it include realistic categories (Electronics, Clothing, etc.)?
- Did it add sortable column headers with sort indicators?
- Did it implement proper pagination (prev/next, page numbers)?
- Did it show "Showing 1-10 of 47 results"?
- Did it color-code status (active=green, draft=gray, archived=red)?
- Did it make the table horizontally scrollable on mobile?

---

## Message 4 — Add product modal
```
Add an "Add Product" button that opens a form. I need name, category, price, stock, description, and status. Validate it properly.
```

**First Principles Check:**
- Did it create a modal component (not navigate to a new page)?
- Did it close modal on backdrop click AND Escape key?
- Did it add proper validation WITHOUT being told what to validate?
  - Name required
  - Price must be positive number
  - Stock must be non-negative integer
- Did it show inline error messages (not alert())?
- Did it clear the form after successful submit?
- Did it add the new product to the table immediately?

---

## Message 5 — Orders page
```
Orders page. Table with order ID, customer, date, total, and status. Status should have color badges. Let me filter by status and click to expand order details.
```

**First Principles Check:**
- Did it generate realistic orders with real-sounding customer names?
- Did it use proper date formatting?
- Did it create status badges (not just text)?
- Did it add a filter dropdown/buttons for status?
- Did it implement expandable rows (click to show items)?
- Did order items list show product name, quantity, price?
- Did it reuse the table pattern from Products (consistent design)?

---

## Message 6 — Responsive
```
Make it responsive. Sidebar should collapse on smaller screens.
```

**First Principles Check:**
- Did it add a hamburger menu for mobile?
- Did it collapse sidebar to icons on tablet?
- Did it make stat cards stack on mobile?
- Did it add a mobile overlay for sidebar?
- Did it close the mobile sidebar when clicking a link?
- Did it NOT break the desktop layout in the process?
- Did tables become scrollable on mobile?

---

## Message 7 — Analytics extras
```
Add a pie chart showing sales by category on the Dashboard. Also add a recent orders widget below the charts.
```

**First Principles Check:**
- Did it add a new chart type (pie) using the same chart library?
- Did the pie chart data match the product categories from the Products page?
- Did the recent orders widget link to the Orders page?
- Did it maintain consistent styling with existing charts?
- Did it lay out the charts in a grid that works on mobile?

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
| 7       |       |       |
| **Avg** |       |       |
