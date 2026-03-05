const config = require('../_lib/config');
const { verifySessionToken } = require('../_lib/session');
const { handlePreflight, sendJson } = require('../_lib/http');

const parseBearer = (req) => {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length === 2 && parts[0].toLowerCase() === 'bearer') return parts[1];
  return '';
};

module.exports = async (req, res) => {
  if (handlePreflight(req, res)) return;
  const token = parseBearer(req);
  const session = verifySessionToken(token, config.sessionSecret);
  sendJson(req, res, 200, {
    isAdmin: !!session,
    admin: session?.u || null,
    loginUrl: `${config.apiBase}/api/auth/github/start`,
  });
};
