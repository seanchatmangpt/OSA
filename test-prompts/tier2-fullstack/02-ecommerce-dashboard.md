# Test: E-Commerce Admin Dashboard

## What it tests
- Complex multi-page React app
- Charts/data visualization
- Table with sorting/filtering/pagination
- Responsive layout
- Multiple component files
- Mock data generation

## Prompt
```
Build an e-commerce admin dashboard with React and TypeScript. Include these pages:

1. **Overview** - Revenue chart (last 7 days bar chart), total orders today, average order value, top 5 products by revenue, recent orders table (last 10)
2. **Products** - Full product table with columns: image, name, SKU, price, stock, status. Add sorting by any column, search, and pagination (10 per page). Include an "Add Product" modal with form validation.
3. **Orders** - Orders table with status badges (pending, processing, shipped, delivered, cancelled). Filter by status and date range. Click to expand and see order items.
4. **Analytics** - Line chart for revenue trend (30 days), pie chart for category breakdown, bar chart for top customers

Use a sidebar navigation with icons. Make it fully responsive - sidebar collapses to icons on tablet, becomes a hamburger menu on mobile. Use recharts for charts. Populate with realistic mock data (at least 50 products, 100 orders).
```

## Expected behavior
- 10+ component files
- Routing setup
- recharts integration
- Responsive sidebar
- Working tables with sort/filter/paginate
- Modal forms
- Realistic mock data
