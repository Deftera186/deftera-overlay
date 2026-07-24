# Codex Copilot Web Search Compatibility

## Goal

Provide an opt-in Gentoo build of `dev-util/codex` that uses the hosted Responses API `web_search` tool with GitHub Copilot-compatible proxies instead of Codex's standalone `web.run` client, which calls the ChatGPT-specific `/alpha/search` endpoint.

## Packaging

Copy the current GURU `dev-util/codex-0.144.6` package into `deftera-overlay`. Add a `copilot-web-search` USE flag and document it in package metadata. The package must remain behaviorally identical to upstream when the flag is disabled.

When `copilot-web-search` is enabled, `src_prepare` applies a versioned patch from the package's `files/` directory. Future Codex bumps must explicitly carry forward or retire the patch after checking upstream behavior.

## Runtime Behavior

The patch changes only web-search tool selection. It prevents the standalone `web.run` extension from replacing the hosted Responses API `web_search` tool. The existing model request then carries a hosted tool specification such as:

```json
{
  "type": "web_search",
  "external_web_access": true
}
```

`copilot-api` already preserves this tool when `useResponsesApiWebSearch` is enabled, allowing GitHub Copilot's Responses-capable model to perform the search. Basic searches and opening result URLs are in scope. Exact parity with standalone operations such as screenshots, finance, weather, sports, and time is out of scope.

No ChatGPT or Anthropic OAuth credential is introduced.

## Failure Handling

If the configured upstream model does not support hosted web search, the upstream error is surfaced normally. Disabling the USE flag and rebuilding restores upstream standalone-search behavior. No fallback to `/alpha/search` is added because that would recreate the unwanted ChatGPT OAuth dependency.

## Verification

Development follows test-first order:

1. Add a focused Codex test that enables the compatibility behavior and asserts that the Responses request contains hosted `web_search` while omitting the `web.run` namespace tool.
2. Run the focused test and confirm it fails before the production patch.
3. Implement the minimal tool-selection change and confirm the focused test passes.
4. Run the relevant Codex web-search test suite.
5. Build and install the package through Portage with `copilot-web-search` enabled.
6. Start a fresh Codex session and perform a live query through `copilot-api`.

## Repository Hygiene

Only the new Codex package, patch, metadata, generated Manifest/cache entries required by the overlay, and this design are in scope. Existing unrelated working-tree changes remain untouched.
