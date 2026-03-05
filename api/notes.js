const config = require('./_lib/config');
const { getFile, putFile } = require('./_lib/github');
const { verifySessionToken } = require('./_lib/session');
const { handlePreflight, sendJson } = require('./_lib/http');

const decodeContent = (base64Content) => {
  const normalized = (base64Content || '').replace(/\n/g, '');
  return Buffer.from(normalized, 'base64').toString('utf8');
};

const parseBearer = (req) => {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length === 2 && parts[0].toLowerCase() === 'bearer') return parts[1];
  return '';
};

module.exports = async (req, res) => {
  try {
    if (handlePreflight(req, res)) return;

    if (req.method === 'GET') {
      const file = await getFile({
        owner: config.repoOwner,
        repo: config.repoName,
        path: config.notesPath,
        branch: config.repoBranch,
        token: config.githubToken,
      });
      const parsed = JSON.parse(decodeContent(file.content));
      const token = parseBearer(req);
      const session = verifySessionToken(token, config.sessionSecret);
      return sendJson(req, res, 200, {
        notes: Array.isArray(parsed.notes) ? parsed.notes : [],
        isAdmin: !!session,
        admin: session?.u || null,
      });
    }

    if (req.method === 'POST') {
      const token = parseBearer(req);
      const session = verifySessionToken(token, config.sessionSecret);
      if (!session) return sendJson(req, res, 401, { error: 'Unauthorized' });
      if (!config.githubToken) return sendJson(req, res, 500, { error: 'Missing GITHUB_TOKEN' });

      const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
      const notes = Array.isArray(body.notes) ? body.notes : [];
      const sanitized = notes
        .map((n) => String(n || '').trim())
        .filter(Boolean)
        .slice(0, 50);

      const file = await getFile({
        owner: config.repoOwner,
        repo: config.repoName,
        path: config.notesPath,
        branch: config.repoBranch,
        token: config.githubToken,
      });

      const content = Buffer.from(
        JSON.stringify({ notes: sanitized }, null, 2) + '\n',
        'utf8'
      ).toString('base64');

      await putFile({
        owner: config.repoOwner,
        repo: config.repoName,
        path: config.notesPath,
        branch: config.repoBranch,
        token: config.githubToken,
        message: `docs: update faith notes by @${session.u}`,
        contentBase64: content,
        sha: file.sha,
      });

      return sendJson(req, res, 200, { ok: true, notes: sanitized });
    }

    sendJson(req, res, 405, { error: 'Method not allowed' });
  } catch (error) {
    sendJson(req, res, error.status || 500, { error: error.message || 'Internal error' });
  }
};
