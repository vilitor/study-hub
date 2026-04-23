# StudyHub Maintenance & Evolution Tracker

## 🐛 Current Bugs (To Fix)
- *No critical bugs at the moment.*

## 🛠️ Fixes Applied
- [x] **History Page Navigation**: Fixed broken routing by adding `AppRoutes.history` mapping in `main.dart`.
- [x] **Registration Card Interaction**: Transformed `_StatCard` into an interactive widget with `InkWell` and added an arrow indicator.
- [x] **Quick Access Layout Broken**: Redesigned `_QuickActionButton` to use a vertical `Column` instead of a horizontal `Row`, allowing the grid to adapt correctly without overflow on small screens.

## 🚀 Future Improvements & Pending Tasks
- [ ] Polish UI constraints for smaller screen sizes.
- [ ] Implement local caching optimizations for faster Notion syncs.
- [ ] Add explicit empty states for History when no logs exist.
- [ ] Implement data export functionality (CSV/PDF) from local storage.
- [ ] Add dark mode support.
