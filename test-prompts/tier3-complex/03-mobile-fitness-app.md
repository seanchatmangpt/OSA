# Test: Mobile Fitness Tracker (React Native/Expo)

## What it tests
- React Native / Expo setup
- Tab navigation
- Multiple screens with content
- Charts in React Native
- Mobile-specific UI patterns

## Prompt
```
Build a fitness tracking mobile app using React Native and Expo with these tabs:

1. **Home** (Dashboard)
   - Today's summary: steps (with circular progress ring), calories burned, active minutes, water intake
   - Weekly activity bar chart
   - Current streak counter with flame icon
   - Quick-start workout buttons (Run, Strength, Yoga, HIIT)

2. **Workouts**
   - List of available workout programs with difficulty badges
   - Each workout shows: name, duration, calories, muscle groups targeted
   - Workout detail screen with exercise list, sets, reps, rest times
   - "Start Workout" button with timer screen
   - Workout history list with dates and stats

3. **Nutrition**
   - Daily calorie tracker with circular progress (consumed vs goal)
   - Macros breakdown (protein, carbs, fat) with progress bars
   - Meal log: breakfast, lunch, dinner, snacks
   - Add food item form with calories and macros
   - Water intake tracker with +250ml buttons

4. **Profile**
   - User info (name, age, weight, height, goal)
   - Stats: total workouts, total calories, best streak
   - Settings: notification preferences, units (metric/imperial), theme
   - Achievement badges grid

Use a modern fitness app design with bold colors. Populate with realistic sample data. Include proper TypeScript types.
```

## Expected behavior
- Expo project structure
- Tab navigation with icons
- Multiple screens per tab (stack navigation)
- Charts (victory-native or similar)
- Circular progress components
- Realistic mock data
- TypeScript throughout
