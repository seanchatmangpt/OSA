# Chain 07: React Native Finance App (5 messages)

Tests: Expo setup, tab navigation, native components, charts, mobile patterns

**KEY: User just says "mobile app" - model must know to use Expo/React Native.**

---

## Message 1 — App shell
```
Build me a mobile finance tracker app. I want tabs for Home, Transactions, and Settings.
```

**First Principles Check:**
- Did it choose Expo + React Native (per system prompt)?
- Did it set up proper Expo project structure?
- Did it create app.json with proper config?
- Did it install react-navigation for tabs?
- Did it install required Expo deps (screens, safe-area-context)?
- Did it add tab icons (lucide-react-native)?
- Did each tab have a placeholder screen (not blank)?
- Did it create proper TypeScript config?
- Did it set up a theme/colors constants file?

---

## Message 2 — Home screen
```
Home screen should show my balance, income vs expenses this month, a weekly chart, and my last 3 transactions. Add a floating + button to add new transactions.
```

**First Principles Check:**
- Did it format the balance as currency ($4,250.00)?
- Did it color income green and expenses red?
- Did it pick a React Native chart library (victory-native, react-native-chart-kit)?
- Did it generate realistic chart data (not all zeros)?
- Did the floating action button position correctly?
- Did it show 3 realistic recent transactions (not "Transaction 1")?
- Did each transaction have a category icon?
- Did it create mock data in a separate file?

---

## Message 3 — Transactions list
```
Transactions screen: scrollable list grouped by date. Show category icon, name, amount, and date for each. Let me filter by income and expenses.
```

**First Principles Check:**
- Did it use SectionList or FlatList (not ScrollView)?
- Did it create section headers for dates (Today, Yesterday, etc.)?
- Did it make section headers sticky?
- Did it generate 15+ realistic transactions?
- Did it add filter tabs (All, Income, Expenses)?
- Did income show as +$amount (green) and expenses as -$amount (red)?
- Did each transaction have a relevant category icon?
- Did it handle empty filter results?

---

## Message 4 — Add transaction
```
The + button should open a screen to add a transaction. Need type (income/expense toggle), amount, category picker, description, and date.
```

**First Principles Check:**
- Did it use stack navigation (push new screen)?
- Did it create a toggle for income/expense?
- Did amount input only allow numbers?
- Did it format amount as currency while typing?
- Did it create a category picker grid with icons?
- Did it add a date picker?
- Did it validate (amount > 0, category required)?
- Did saving go back to previous screen?
- Did the new transaction appear in the list?

---

## Message 5 — Settings + polish
```
Settings screen with profile info, currency preference, dark/light theme, and an export button. Also add a monthly budget - if I go over, show a warning on Home.
```

**First Principles Check:**
- Did it create settings sections with proper grouping?
- Did it add a theme toggle that actually switches themes?
- Did the theme apply to ALL screens?
- Did it persist theme preference?
- Did it add a budget input field?
- Did it add a warning/banner on Home when expenses > budget?
- Did it calculate expenses vs budget correctly?
- Did it add loading/skeleton states on data-heavy screens?
- Did it handle the export button (even as mock)?

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
