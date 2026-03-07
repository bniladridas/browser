const config = require('../_lib/config');
const { verifySessionToken, parseBearerToken } = require('../_lib/session');
const { handlePreflight, sendJson } = require('../_lib/http');

module.exports = async (req, res) => {
  if (handlePreflight(req, res)) return;
  const token = parseBearerToken(req);
  const session = verifySessionToken(token, config.sessionSecret);
  sendJson(req, res, 200, {
    isAdmin: !!session,
    admin: session?.u || null,
    loginUrl: `${config.apiBase}/api/auth/github/start`,
  });
};
