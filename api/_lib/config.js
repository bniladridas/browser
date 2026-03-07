const parseList = (input) =>
  (input || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean);

const config = {
  githubClientId: process.env.GITHUB_CLIENT_ID,
  githubClientSecret: process.env.GITHUB_CLIENT_SECRET,
  githubToken: process.env.GITHUB_TOKEN,
  sessionSecret: process.env.SESSION_SECRET,
  repoOwner: process.env.NOTES_REPO_OWNER || 'bniladridas',
  repoName: process.env.NOTES_REPO_NAME || 'browser',
  repoBranch: process.env.NOTES_REPO_BRANCH || 'gh-pages',
  notesPath: process.env.NOTES_FILE_PATH || 'data/faith-notes.json',
  frontendOrigin: process.env.FRONTEND_ORIGIN || 'https://bniladridas.github.io',
  allowedOrigins: parseList(process.env.ALLOWED_ORIGINS || 'https://bniladridas.github.io'),
  apiBase: process.env.API_BASE || '',
  adminUsers: parseList(process.env.ADMIN_USERS || '').map((v) => v.toLowerCase()),
};

const envNameByKey = {
  githubClientId: 'GITHUB_CLIENT_ID',
  githubClientSecret: 'GITHUB_CLIENT_SECRET',
  githubToken: 'GITHUB_TOKEN',
  sessionSecret: 'SESSION_SECRET',
  apiBase: 'API_BASE',
};

const requireConfig = (keys = []) => {
  const missing = keys.filter((key) => !config[key]).map((key) => envNameByKey[key] || key);
  if (missing.length > 0) {
    const error = new Error(`Missing required environment variables: ${missing.join(', ')}`);
    error.status = 500;
    throw error;
  }
};

module.exports = {
  ...config,
  requireConfig,
};
