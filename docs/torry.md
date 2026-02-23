# Torry-powered home

## Overview
- The default `about:browser-home` tab now renders a Torry-branded home screen with a contextual headline, feature chips, and quick actions instead of the previous generic branding panel.
- A dedicated Torry search input targets `https://www.torry.io/search/?q=…` and reuses the browser tab via `_performTorrySearch`, keeping the user inside the browser while surfacing Torry results.

## Experience
- The search field auto-focuses when empty and submits through `_performTorrySearch`, which encodes the query and delegates to `_loadUrl`.
- Quick-action buttons launch Torry’s search landing page, onion directory, and anonymous-view section so the home view double-checks major Torry flows.
- The search input, buttons, and feature chips use the app’s color scheme and responsive layout to feel cohesive on desktops.

## Maintenance
- Torry search state is tracked per tab via `TabData.torrySearchController` and `TabData.torrySearchFocusNode`, and both are disposed when tabs are removed or the page is disposed to avoid leaks.
- Torry-related UI lives in `_buildTorryHomeView` so future home-screen experiments can swap in updated panels without touching the browser core logic.
