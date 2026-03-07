const jsonHeaders = {
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
};

const ghFetch = async (url, token, init = {}) => {
  const headers = {
    ...jsonHeaders,
    ...(init.headers || {}),
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(url, { ...init, headers });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { message: text };
  }
  if (!res.ok) {
    const err = new Error(data?.message || `GitHub request failed (${res.status})`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
};

const getFile = async ({ owner, repo, path, branch, token }) => {
  const encodedOwner = encodeURIComponent(owner);
  const encodedRepo = encodeURIComponent(repo);
  const encodedPath = encodeURIComponent(path).replace(/%2F/g, '/');
  return ghFetch(
    `https://api.github.com/repos/${encodedOwner}/${encodedRepo}/contents/${encodedPath}?ref=${encodeURIComponent(branch)}`,
    token
  );
};

const putFile = async ({ owner, repo, path, branch, token, message, contentBase64, sha }) => {
  const encodedOwner = encodeURIComponent(owner);
  const encodedRepo = encodeURIComponent(repo);
  const encodedPath = encodeURIComponent(path).replace(/%2F/g, '/');
  return ghFetch(
    `https://api.github.com/repos/${encodedOwner}/${encodedRepo}/contents/${encodedPath}`,
    token,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message,
        content: contentBase64,
        branch,
        sha,
      }),
    }
  );
};

module.exports = {
  ghFetch,
  getFile,
  putFile,
};
