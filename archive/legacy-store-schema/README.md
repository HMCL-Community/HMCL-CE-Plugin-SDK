# HMCL Plugin Store Remote

This repository is the remote index for the HMCL plugin store.

## Files

- `registry.json`: store index and plugin metadata.
- `plugins/<plugin-id>/manifest.json`: version list for a plugin.
- `plugins/<plugin-id>/<version>.jar`: plugin package files.

## `registry.json`

```json
{
  "version": 1,
  "name": "HMCL Plugin Store",
  "plugins": [
    {
      "id": "example-plugin",
      "name": "Example Plugin",
      "description": "A short plugin description.",
      "author": "HMCL",
      "repository": "https://github.com/example/example-plugin",
      "manifest": "plugins/example-plugin/manifest.json",
      "category": "utility",
      "tags": ["example", "utility"]
    }
  ]
}
```

## Plugin `manifest.json`

```json
{
  "id": "example-plugin",
  "name": "Example Plugin",
  "description": "A short plugin description.",
  "author": "HMCL",
  "license": "GPL-3.0-or-later",
  "versions": [
    {
      "version": "1.0.0",
      "downloadUrl": "plugins/example-plugin/1.0.0.jar",
      "checksum": "sha256:...",
      "size": 102400,
      "releaseDate": "2026-07-14",
      "releaseNotes": "Initial release.",
      "minLauncherVersion": "3.6.0"
    }
  ]
}
```

Relative URLs are resolved from the registry or manifest URL.

## Recommended categories

- `utility`
- `integration`
- `theme`
- `tool`
- `experimental`

## Updating a plugin

1. Upload the new jar under `plugins/<plugin-id>/`.
2. Append a new item to `plugins/<plugin-id>/manifest.json` `versions`.
3. Keep versions sorted from old to new. HMCL uses the latest item as the latest version.
