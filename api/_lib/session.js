const crypto = require('crypto');

const base64url = (input) =>
  Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

const fromBase64url = (input) => {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const pad = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + pad, 'base64').toString('utf8');
};

const sign = (value, secret) =>
  crypto.createHmac('sha256', secret).update(value).digest('hex');

const createSignedPayload = (payload, secret) => {
  const encoded = base64url(JSON.stringify(payload));
  const sig = sign(encoded, secret);
  return `${encoded}.${sig}`;
};

const verifySignedPayload = (token, secret) => {
  if (!token || !secret) return null;
  const [encoded, sig] = token.split('.');
  if (!encoded || !sig) return null;
  const expected = sign(encoded, secret);
  const sigBuf = Buffer.from(sig);
  const expectedBuf = Buffer.from(expected);
  if (sigBuf.length !== expectedBuf.length) return null;
  if (!crypto.timingSafeEqual(sigBuf, expectedBuf)) return null;
  try {
    return JSON.parse(fromBase64url(encoded));
  } catch (_) {
    return null;
  }
};

const createSessionToken = ({ username, ttlSec = 60 * 60 * 24 }, secret) =>
  createSignedPayload(
    {
      u: username,
      exp: Math.floor(Date.now() / 1000) + ttlSec,
    },
    secret
  );

const verifySessionToken = (token, secret) => {
  const payload = verifySignedPayload(token, secret);
  if (!payload?.u || !payload?.exp) return null;
  if (Math.floor(Date.now() / 1000) > payload.exp) return null;
  return payload;
};

const parseCookies = (cookieHeader) => {
  const out = {};
  if (!cookieHeader) return out;
  for (const part of cookieHeader.split(';')) {
    const [k, ...rest] = part.trim().split('=');
    if (!k) continue;
    out[k] = decodeURIComponent(rest.join('='));
  }
  return out;
};

const parseBearerToken = (req) => {
  const auth = req?.headers?.authorization || '';
  const parts = auth.split(' ');
  if (parts.length === 2 && parts[0].toLowerCase() === 'bearer') return parts[1];
  return '';
};

const isAllowedReturnTo = (returnTo, frontendOrigin, allowedOrigins = []) => {
  if (!returnTo || !frontendOrigin) return false;
  try {
    const target = new URL(returnTo);
    const allowedOriginsSet = new Set([frontendOrigin, ...allowedOrigins]);
    const normalizedAllowed = [...allowedOriginsSet].map((origin) => new URL(origin).origin);
    if (!['http:', 'https:'].includes(target.protocol)) return false;
    return normalizedAllowed.includes(target.origin);
  } catch (_) {
    return false;
  }
};

module.exports = {
  createSessionToken,
  verifySessionToken,
  createSignedPayload,
  verifySignedPayload,
  parseCookies,
  parseBearerToken,
  isAllowedReturnTo,
};
