const { handlePreflight, sendJson } = require('./_lib/http');

module.exports = async (req, res) => {
  if (handlePreflight(req, res)) return;

  // Stateless auth: token is bearer/localStorage on the client, so logout is
  // performed client-side by removing the token.
  return sendJson(req, res, 200, { ok: true, stateless: true });
};
