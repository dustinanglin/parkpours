# Park Pours

A passport-stamp book for theme park drinks, designed for the iPhone Duo.
Check a drink off, give it a verdict, rank it against the rest of the park.

Prototype of design Concept A ("Passport office"): closed, it shows the
passport cover; open, the fold is the spine, with the park checklist on the
left page and the stamps on the right.

## Layout

- **Two-page spread** when the window is at least 700 x 500 points (the open Duo).
- **Cover + one page at a time** on anything smaller: the Duo's cover screen
  or a regular iPhone. Swipe between the checklist and the stamps.

The rule lives in `BookLayout.isOpen` in `ParkPours/Theme/Theme.swift`.

## Building locally

The Xcode project is generated from `project.yml`:

```sh
brew install xcodegen
xcodegen generate
open ParkPours.xcodeproj
```

## TestFlight from GitHub Actions

`.github/workflows/testflight.yml` compiles on every push and pull request,
and on `main` also archives and uploads to TestFlight.

One-time setup, all in a browser:

1. In the Apple Developer portal, register a bundle ID (for example
   `com.yourname.parkpours`).
2. In App Store Connect, create an app that uses that bundle ID.
3. In App Store Connect, Users and Access, Integrations, create an
   App Store Connect API key (Admin role) and download the `.p8` file.
4. In the GitHub repo, Settings, Secrets and variables, Actions, add:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | The key's ID |
| `ASC_ISSUER_ID` | The issuer ID shown above the key list |
| `ASC_PRIVATE_KEY` | The full contents of the `.p8` file |
| `APPLE_TEAM_ID` | Your 10-character team ID |
| `BUNDLE_ID` | The bundle ID from step 1 |

The build number is the workflow run number.

## Reporting bugs from the app

Shake the phone, or long-press the small running header at the top of any
page, to start a bug report. The app grabs the screen as it was, you add a
title, and it files a GitHub issue in this repo labelled `in-app-feedback`,
with the app version, iOS version, device, window size and layout attached.

One-time setup on the device: create a fine-grained personal access token at
GitHub, Settings, Developer settings, limited to this repository, with
**Issues** and **Contents** set to read and write. Paste it into the report
form the first time; it is kept in the device's Keychain, not in the repo.

Screenshots are committed to the `feedback-screenshots` branch and linked from
the issue, because GitHub's API cannot attach images to issues. That is why
the token needs Contents access. The repo is public, so issues and screenshots
are too.

## Not in this prototype yet

- Drink photos
- Bundled fonts (system serif, mono and condensed stand in for the mockup's)
- Page-turn animation
- The starter drink list in `SeedData.swift` is sample content written from
  memory, not checked against current menus
