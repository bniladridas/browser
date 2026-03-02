// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

const String webAuthnScript = '''
(function() {
  // Store pending requests by ID
  const pendingRequests = new Map();
  let requestIdCounter = 0;

  // Single callback for Flutter to resolve/reject requests
  window.resolveWebAuthnRequest = function(requestId, success, data) {
    const pending = pendingRequests.get(requestId);
    if (!pending) return;

    if (success) {
      pending.resolve(data);
    } else {
      pending.reject(new Error(data));
    }
    pendingRequests.delete(requestId);
  };

  // Test that script is running
  if (window.WebAuthnChannel) {
    window.WebAuthnChannel.postMessage('WebAuthn script loaded');
  }

  if (!window.PublicKeyCredential) {
    if (window.WebAuthnChannel) {
      window.WebAuthnChannel.postMessage('WebAuthn not supported');
    }
    return;
  }

  if (window.WebAuthnChannel) {
    window.WebAuthnChannel.postMessage('WebAuthn API available');
  }

  // Intercept navigator.credentials.create
  const originalCreate = navigator.credentials.create.bind(navigator.credentials);
  navigator.credentials.create = async function(options) {
    if (window.WebAuthnChannel) {
      window.WebAuthnChannel.postMessage('WebAuthn create called');
    }

    if (options.publicKey) {
      try {
        const requestId = ++requestIdCounter;

        // Send only necessary data, no PII logging
        if (window.WebAuthnChannel && window.WebAuthnChannel.postMessage) {
          window.WebAuthnChannel.postMessage(JSON.stringify({
            type: 'create',
            requestId: requestId,
            options: {
              challenge: Array.from(new Uint8Array(options.publicKey.challenge)),
              rp: options.publicKey.rp,
              user: {
                id: Array.from(new Uint8Array(options.publicKey.user.id)),
                name: options.publicKey.user.name,
                displayName: options.publicKey.user.displayName
              }
            }
          }));
        } else {
          console.warn('WebAuthnChannel not available, using fallback');
          return originalCreate(options);
        }

        // Wait for response from Flutter
        return new Promise((resolve, reject) => {
          pendingRequests.set(requestId, { resolve, reject });

          // Timeout after 60 seconds
          setTimeout(() => {
            if (pendingRequests.has(requestId)) {
              pendingRequests.delete(requestId);
              reject(new Error('WebAuthn timeout'));
            }
          }, 60000);
        });
      } catch (e) {
        if (window.WebAuthnChannel) {
          // Only log error message, not details
          window.WebAuthnChannel.postMessage('WebAuthn create error');
        }
        throw e;
      }
    }
    return originalCreate(options);
  };

  // Intercept navigator.credentials.get
  const originalGet = navigator.credentials.get.bind(navigator.credentials);
  navigator.credentials.get = async function(options) {
    if (window.WebAuthnChannel) {
      window.WebAuthnChannel.postMessage('WebAuthn get called');
    }

    if (options.publicKey) {
      try {
        const requestId = ++requestIdCounter;

        // Send only necessary data
        if (window.WebAuthnChannel && window.WebAuthnChannel.postMessage) {
          window.WebAuthnChannel.postMessage(JSON.stringify({
            type: 'get',
            requestId: requestId,
            options: {
              challenge: Array.from(new Uint8Array(options.publicKey.challenge)),
              rpId: options.publicKey.rpId,
              allowCredentials: options.publicKey.allowCredentials?.map(c => ({
                id: Array.from(new Uint8Array(c.id)),
                type: c.type
              }))
            }
          }));
        } else {
          console.warn('WebAuthnChannel not available, using fallback');
          return originalGet(options);
        }

        // Wait for response from Flutter
        return new Promise((resolve, reject) => {
          pendingRequests.set(requestId, { resolve, reject });

          // Timeout after 60 seconds
          setTimeout(() => {
            if (pendingRequests.has(requestId)) {
              pendingRequests.delete(requestId);
              reject(new Error('WebAuthn timeout'));
            }
          }, 60000);
        });
      } catch (e) {
        if (window.WebAuthnChannel) {
          // Only log error message, not details
          window.WebAuthnChannel.postMessage('WebAuthn get error');
        }
        throw e;
      }
    }
    return originalGet(options);
  };

  if (window.WebAuthnChannel) {
    window.WebAuthnChannel.postMessage('WebAuthn interceptors installed');
  }
})();
''';
