# Park Pours

A passport-stamp book for theme park drinks, designed for the iPhone Duo.
Check a drink off, give it a verdict, rank it against the rest of the park.

Prototype of design Concept A ("Passport office"): closed, it shows the
passport cover; open, the fold is the spine, with the park checklist on the
left page and the stamps on the right.

## Layout

- **Two-page spread** when the window is at least 700 points on its long side
  and 500 on its short side (the open Duo, which reports 951 x 669).
- **Cover + one page at a time** on anything smaller: the Duo's cover screen
  or a regular iPhone.

The app only supports the upright (portrait) orientation. On the Duo that is
the right one in both states: closed it is the tall cover screen, and open it
is the wide inner screen with the fold as the spine.

The Duo's inner screen rotates apps anyway. When that happens the app turns
its own pages back (`FoldAwareContainer`), so the spread stays fixed to the
device with the fold as the spine. System pieces such as the keyboard and the
bug-report sheet still follow the screen's rotation.

Either way the passport is a book: swipe to turn the page. Closed, the cover
is the first page, so a swipe opens it. Then come the park list and the
rankings, then "all stamps", one page per park that has
a stamp. Tapping a park opens its checklist and stamps.

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

## The catalog

Parks and drinks come from two places, merged in the app:

- **The official catalog**: one hand-curated file, `catalog.json`, on the
  `catalog` branch. The app ships with a copy and downloads the newest one
  each time it starts, so catalog changes need no new build. It is curated by
  hand on purpose: it is not pulled from any third-party menu site.
- **Personal drinks and parks**: anything a person adds in the app. These stay
  on their phone and are marked "added by you".

Stamps, notes, photos and rankings are always personal and stay on the phone.

**Scan a menu.** On a park's checklist, "Scan a menu" reads the text off a
photo of a menu (on the phone, nothing is uploaded) and lets you tick the
lines that are drinks. They are added as personal drinks.

**Curating the catalog.** With a GitHub token saved in the app (the same one
used for bug reports), a personal drink's entry page shows "Publish to
catalog". That lets you tidy the name, venue and area and writes the drink
into `catalog.json`. The drink keeps its id, so your stamp carries over.

The file can also be edited directly on GitHub. Each drink needs a unique
`id` and a `name`; `venue`, `area`, `nonAlcoholic` and `retired` are optional.
Add one to `version` when you edit by hand. To take a drink off the menu, set
`"retired": true` instead of deleting it, so existing stamps keep their drink.

## Non-alcoholic drinks

Mocktails and other specialty drinks can be logged too. Tick "Non-alcoholic"
on the entry page of a drink you added, or choose "Add as non-alcoholic" when
adding one. For catalog drinks the tag is set in the catalog.
Tagged drinks show a small "Zero proof" mark in the checklist and rankings.

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

- Taking a drink photo with the camera from inside the app (photos are added
  from the library and stored on the device)
- Bundled fonts (system serif, mono and condensed stand in for the mockup's)
- The starter drink list in `SeedData.swift` is sample content written from
  memory, not checked against current menus
