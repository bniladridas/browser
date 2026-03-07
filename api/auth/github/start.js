const crypto = require('crypto');
const config = require('../../_lib/config');
const { createSignedPayload, isAllowedReturnTo } = require('../../_lib/session');

module.exports = async (req, res) => {
  try {
    config.requireConfig(['githubClientId', 'sessionSecret', 'apiBase']);
  } catch (error) {
    res.statusCode = 500;
    return res.end(error.message || 'Missing auth configuration');
  }

  const url = new URL(req.url, config.apiBase);
  const returnTo = url.searchParams.get('return_to') || `${config.frontendOrigin}/browser/book-of-faith.html`;
  if (!isAllowedReturnTo(returnTo, config.frontendOrigin, config.allowedOrigins)) {
    res.statusCode = 400;
    return res.end('Invalid return_to origin');
  }

  const statePayload = {
    nonce: crypto.randomBytes(8).toString('hex'),
    returnTo,
    exp: Math.floor(Date.now() / 1000) + 600,
  };
  const state = createSignedPayload(statePayload, config.sessionSecret);

  const redirectUri = `${config.apiBase}/api/auth/github/callback`;
  const params = new URLSearchParams({
    client_id: config.githubClientId,
    redirect_uri: redirectUri,
    state,
    scope: 'read:user user:email',
  });

  res.statusCode = 302;
  res.setHeader('Location', `https://github.com/login/oauth/authorize?${params.toString()}`);
  res.end();
};
