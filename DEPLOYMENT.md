# GitHub Deployment Guide 🚀

Follow these instructions to publish **StudyHub** to your professional GitHub portfolio using industry best practices.

## 1. Local Cleanup
Before initializing the repository, ensure no local or temporary files are present:
```bash
flutter clean
```

## 2. Initialize Git
If you haven't initialized Git yet, run:
```bash
git init
git branch -M main
```

## 3. First Commit (Conventional Commits)
Add all files (the `.gitignore` will automatically exclude sensitive ones) and create the initial commit:
```bash
git add .
git commit -m "feat: initial release of StudyHub Study Management App"
```
*Note: We use the `feat:` prefix following the [Conventional Commits](https://www.conventionalcommits.org/) specification.*

## 4. Create GitHub Repository
1. Go to [GitHub](https://github.com/new).
2. Name the repository `study-hub` or similar.
3. Keep it **Public** for portfolio visibility.
4. **Do not** initialize with README or license (you already have them).

## 5. Push to GitHub
Copy the remote URL from GitHub and run:
```bash
git remote add origin https://github.com/YOUR_USERNAME/study-hub.git
git push -u origin main
```

## 6. Branching Strategy
For professional projects, avoid pushing directly to `main` for new features. Use a `develop` branch:
```bash
git checkout -b develop
# Make changes...
git add .
git commit -m "docs: update setup instructions"
git push origin develop
```

## 7. Tagging a Release
To mark your first stable version (v1.0.0):
```bash
git tag -a v1.0.0 -m "First stable release"
git push origin v1.0.0
```

---

### ✅ Portfolio Checklist
- [ ] README.md is present and looks good on GitHub.
- [ ] No `.env` files are in the repository.
- [ ] Project builds successfully on a clean machine.
- [ ] Security/Privacy sections are clearly visible.

**Happy Deployment!**
