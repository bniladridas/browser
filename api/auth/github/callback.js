const config = require('../../_lib/config');
const { ghFetch } = require('../../_lib/github');
const { verifySignedPayload, createSessionToken, isAllowedReturnTo } = require('../../_lib/session');

module.exports = async (req, res) => {
  try {
    if (!config.apiBase || !config.sessionSecret) {
      res.statusCode = 500;
      return res.end('Missing auth configuration');
    }

    const url = new URL(req.url, config.apiBase);
    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');

    if (!code || !state) {
      res.statusCode = 400;
      return res.end('Missing OAuth parameters');
    }

    const statePayload = verifySignedPayload(state, config.sessionSecret);
    if (!statePayload?.returnTo || !statePayload?.exp) {
      res.statusCode = 400;
      return res.end('Invalid OAuth state');
    }
    if (Math.floor(Date.now() / 1000) > statePayload.exp) {
      res.statusCode = 400;
      return res.end('Expired OAuth state');
    }
    if (!isAllowedReturnTo(statePayload.returnTo, config.frontendOrigin)) {
      res.statusCode = 400;
      return res.end('Invalid return target');
    }

    const tokenResp = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_id: config.githubClientId,
        client_secret: config.githubClientSecret,
        code,
        redirect_uri: `${config.apiBase}/api/auth/github/callback`,
      }),
    });
    const tokenData = await tokenResp.json();
    if (!tokenResp.ok || !tokenData.access_token) {
      res.statusCode = 401;
      return res.end('GitHub OAuth failed');
    }

    const user = await ghFetch('https://api.github.com/user', tokenData.access_token);
    const login = String(user.login || '').toLowerCase();
    if (!login || !config.adminUsers.includes(login)) {
      res.statusCode = 403;
      return res.end('Not in admin allowlist');
    }

    const sessionToken = createSessionToken({ username: login, ttlSec: 60 * 60 * 24 * 7 }, config.sessionSecret);
    const target = new URL(statePayload.returnTo);
    target.hash = `admin_token=${encodeURIComponent(sessionToken)}&admin_user=${encodeURIComponent(login)}`;

    res.statusCode = 302;
    res.setHeader('Location', target.toString());
    res.end();
  } catch (error) {
    res.statusCode = 500;
    res.end(error.message || 'OAuth callback failed');
  }
};
