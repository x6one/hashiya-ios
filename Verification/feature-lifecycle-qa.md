# Pre-upload functional verification

The same commit must pass `test (iPhone)` and `test (iPad)` in `ios-check.yml` before native packaging/upload. Existing XCTest and XCUITest checks run first; Maestro is an additional required step in both jobs. A failed or skipped test step prevents packaging. Previous-commit results do not qualify.

Maestro CLI 2.11.0 runs locally on GitHub's macOS simulator runners. No Maestro Cloud account, uploaded user documents or AI analysis are used. Each flow starts with disposable clean simulator data. Relaunch checks do not clear data. Debug-only `maestroTesting` disables automatic test-demo seeding; no production feature or validation is bypassed.

| Feature | Required scenario | Runner |
| --- | --- | --- |
| Notebook/library | Create, rename, move out of root, survive relaunch, trash, restore, permanently delete, verify after relaunch | Maestro |
| Sections | Create, move into, delete section, preserve notebook in root | Maestro + XCTest |
| Flashcards | Create question/answer, reveal, edit, survive relaunch, delete, verify after relaunch | Maestro + XCTest |
| Linked recordings | Record/save, delete, verify after relaunch, deny microphone, still open writing | Maestro + XCTest |
| Recording references | Delete one clip and its markers while preserving another; omit missing clips | XCTest |
| Document pages | Add paper templates, delete, undo, reload; remap sidecar anchors; last-page safeguard | XCUITest + XCTest |
| Independent margins | Add, write, navigate, delete, restore content, relaunch, last-page safeguard | XCUITest + XCTest |
| Handwriting/layout | Draw strokes, resize split, fit sheet, rotate, full screen, relaunch; verify visible ink pixels | XCUITest |
| Text annotations | Add, persist, export | XCUITest + XCTest |
| Import/export/Office | Native Files providers, PDF/PowerPoint bytes, originals/media, conversion | XCUITest + XCTest |
| Backup/search/recovery | Preserve sidecars; restore collisions; search; interrupted page transaction recovery | XCTest |
| Review entry | Welcome, populated editable samples and visible tools without account | XCUITest |

Reports and failure screenshots are retained in `diagnostics-iPhone` and `diagnostics-iPad`. CI does not prove every possible device, Office input or user gesture; physical Apple Pencil checks remain useful. Investigate any failed assertion before upload.

Sources: [Maestro](https://github.com/mobile-dev-inc/Maestro), [CLI installation](https://docs.maestro.dev/maestro-cli/how-to-install-maestro-cli), [permissions](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/permissions), [Apple XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation).
