# Tayya Studio 2.0 — store artwork

Six Arabic compositions per device, based on actual production screenshots. Editable HTML/CSS and unchanged raw PNG inputs are included with each output. The app is always the main visual; no generated interface, synthetic microphone image, price, ranking, subscription claim or Apple badge is used.

Required current output: medium Dynamic Island iPhone1206x2622, iPad13-inch2064x2752, RGB PNG without alpha. Capture each device natively; the renderer rejects another phone's source size. All image/text bounds, original hashes and exported hashes are recorded. A large-phone1320x2868 output is optional and accepts only matching native sources.

`Tools/render_store_artwork.py` uses installed Chromium/Chrome and Python Playwright/Pillow to typeset vectors, exact Arabic text and real image inputs. These are artwork tools only; no package or font is added to the iOS app. Font files are the existing unmodified Noto Kufi Arabic Bold and Noto Sans Arabic Regular, distributed under SIL Open Font License1.1; see fonts/OFL-1.1.txt. Brand mark geometry comes from App/TayyaTheme.swift's TayyaFold.

Initial local v1 layouts used the qualified c07e69e captures as design proofs. Final store imagery is recaptured with original, self-authored accounting lesson copy in the DEBUG-only ProductionReviewFixtures, replacing technical test descriptions. The fixture remains isolated; normal user files and Release app behavior do not change. Existing screenshot test assertions remain intact.

Apple references checked2026-10-25: https://developer.apple.com/help/app-review/guideline-reference/2-3-3-screenshots/ and https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ . Compliance preparation does not guarantee Apple's approval.
