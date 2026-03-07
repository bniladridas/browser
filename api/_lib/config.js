const parseList = (input) =>
  (input || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean);

module.exports = {
  githubClientId: process.env.GITHUB_CLIENT_ID || '',
  githubClientSecret: process.env.GITHUB_CLIENT_SECRET || '',
  githubToken: process.env.GITHUB_TOKEN || '',
  sessionSecret: process.env.SESSION_SECRET || '',
  repoOwner: process.env.NOTES_REPO_OWNER || 'bniladridas',
  repoName: process.env.NOTES_REPO_NAME || 'browser',
  repoBranch: process.env.NOTES_REPO_BRANCH || 'gh-pages',
  notesPath: process.env.NOTES_FILE_PATH || 'data/faith-notes.json',
  frontendOrigin: process.env.FRONTEND_ORIGIN || 'https://bniladridas.github.io',
  allowedOrigins: parseList(process.env.ALLOWED_ORIGINS || 'https://bniladridas.github.io'),
  apiBase: process.env.API_BASE || '',
  adminUsers: parseList(process.env.ADMIN_USERS || '').map((v) => v.toLowerCase()),
};
