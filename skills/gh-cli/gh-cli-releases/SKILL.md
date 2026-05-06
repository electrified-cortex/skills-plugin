---
name: gh-cli-releases
description: Manage GitHub releases via gh release. Full lifecycle: create, publish, upload assets, edit, delete. Triggers - create release, github release, publish release, upload release asset, manage releases.
---

## Listing

```bash
gh release list
gh release list --exclude-drafts --limit 1   # latest published; drafts excluded
# Note: gh release view without tag → latest release, but returns empty if latest is draft
```

## Create — Direct Publish (requires existing tag pushed first)

```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes" --target main
gh release create v1.0.0 --notes-file CHANGELOG.md
```

## Create — Draft then Publish

```bash
gh release create v1.0.0 --draft --notes "..."
gh release edit v1.0.0 --draft=false
```

## Pre-releases

```bash
gh release create v1.0.0-rc1 --prerelease --notes "..."
```

## Upload Assets

```bash
gh release upload v1.0.0 ./dist/app.tar.gz ./dist/app.zip
```

## Edit Release

```bash
gh release edit v1.0.0 --title "new title" --notes "updated notes"
gh release edit v1.0.0 --prerelease=false
```

## Delete

```bash
gh release delete v1.0.0 --yes
gh release delete-asset v1.0.0 app.tar.gz
```

## Download Assets

```bash
gh release download v1.0.0 --pattern "*.tar.gz" --dir ./downloads
gh release download v1.0.0 --archive zip
```

## Scope

`gh release` only. Doesn't manage Git tags directly, generate changelogs from commits, handle attestations/signing, or configure CI/CD release automation.
