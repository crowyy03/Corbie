# App Store metadata

One file per language: `en.md`, `es.md`, `fr.md`, `de.md`, `it.md`. English is the primary
localization; the other four are the launch markets from spec section 14.

## Where each field goes in App Store Connect

App Store Connect keeps these fields in two different places. The ones that change per version
sit under the version you are preparing; the ones that describe the app itself sit under the app.

| Field in our files | Where in App Store Connect | Limit | Editable without review |
|---|---|---|---|
| Name | App Store tab, version page, "Name" | 30 characters | No, ships with a version |
| Subtitle | App Store tab, version page, "Subtitle" | 30 characters | No, ships with a version |
| Keywords | App Store tab, version page, "Keywords" under App Information for that localization | 100 characters | No, ships with a version |
| Promotional text | App Store tab, version page, "Promotional Text" | 170 characters | Yes, any time |
| Description | App Store tab, version page, "Description" | 4000 characters | No, ships with a version |
| What's new | App Store tab, version page, "What's New in This Version" | 4000 characters | No, ships with a version |
| Screenshot captions | Burned into the screenshot images, not a field | - | No, ships with a version |

Every one of these fields is per language. Add the four extra localizations under the version
page ("Add Language"), then paste each file into its own language.

## Rules the copy already follows

- Keywords are comma separated with no spaces after the commas. A space costs a character.
- No keyword repeats a word from the name or the subtitle. App Store search already indexes
  those two fields, so repeating them wastes the 100 characters.
- No competitor names anywhere. Apple rejects them and it is a trademark risk.
- No exclamation marks, no emoji, no "love" or "couple" in a name, subtitle or headline.
  Brand book section 3 and 5.
- The first three lines of the description carry the value. On the store page everything after
  about three lines is behind "more", and most people never tap it.

## What still has to be checked by hand

- The prices printed in the descriptions come from spec section 10: the English listing says
  4.99 and 29.99, the four European listings say 5,99 and 39,99. The price tier chosen in
  App Store Connect has to match those lines in every storefront the listing serves, and the
  German, Spanish, French and Italian listings each serve more than one country.
- Screenshot captions are the copy for the six screens in spec section 12. The image work is
  separate; the captions here are what goes on the art.
- Age rating 4+, categories Lifestyle (primary) and Productivity (secondary), per spec 12.
