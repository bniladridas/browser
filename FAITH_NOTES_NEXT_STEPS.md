# Faith Notes - Next Steps

## 1) Deploy API on Vercel
1. Import this repo in Vercel.
2. Set project root to this branch/repo as usual (no special subdir needed).
3. Deploy so `/api/*` endpoints become live.

## 2) Configure Vercel Environment Variables
Set these in Vercel Project Settings -> Environment Variables:

- `API_BASE` = your Vercel URL (example: `https://browser-notes-api.vercel.app`)
- `FRONTEND_ORIGIN` = `https://bniladridas.github.io`
- `ALLOWED_ORIGINS` = `https://bniladridas.github.io`
- `SESSION_SECRET` = long random secret
- `GITHUB_CLIENT_ID` = GitHub OAuth app client id
- `GITHUB_CLIENT_SECRET` = GitHub OAuth app client secret
- `ADMIN_USERS` = comma-separated GitHub usernames allowed to edit notes
- `GITHUB_TOKEN` = GitHub token with repo contents write access
- `NOTES_REPO_OWNER` = `bniladridas`
- `NOTES_REPO_NAME` = `browser`
- `NOTES_REPO_BRANCH` = `gh-pages`
- `NOTES_FILE_PATH` = `data/faith-notes.json`

## 3) Configure GitHub OAuth App
In GitHub OAuth App settings:

- Authorization callback URL:
  - `https://<your-vercel-domain>/api/auth/github/callback`

## 4) Point Frontend to API
In `book-of-faith.html`, set:

- `window.NOTES_API_BASE` (preferred), or
- replace default placeholder `https://your-notes-api.vercel.app` with your real Vercel URL.

## 5) Verify End-to-End
1. Open `https://bniladridas.github.io/browser/book-of-faith.html`
2. Click **Login with GitHub**
3. Confirm admin section appears
4. Edit notes and click **Save**
5. Confirm `data/faith-notes.json` updates in `gh-pages`
