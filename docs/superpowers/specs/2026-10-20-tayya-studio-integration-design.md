# Tayya Studio 2.0 production integration

The user's Phase C brief and approval of the 297-image gallery authorize this integration. This is an integration of approved presentation, not a new design or a replacement application.

## Sources and rollback

- Production baseline: `dbdb264bf86a6606be095aad22cd303ad01e2071`.
- Baseline evidence: [39342393075](https://github.com/x6one/hashiya-ios/actions/runs/39342393075): each device passed 68 XCTest, 32 XCUITest and three Maestro flows; native Office packaging also passed. The older pending status documents do not supersede this evidence.
- Approved Studio: `3b9872a9e26fbfa2ce102b9d2cdd7d1bb7f5f480`; executable design qualification at `e94c2cbb6f6914e0ebb21ded090beaa54013e4df`, run 39491602063. Gallery: 39495383721.
- Work only on `integration/tayya-studio-2`, an isolated worktree branched from the production baseline. Neither source branch is changed. Every integration commit remains independently reviewable.

## Ownership and mapping

| Approved presentation source | Retained production owner | Integration files / protection |
| --- | --- | --- |
| StudioTheme / StudioMetrics / button components | TayyaTheme and native SwiftUI controls | TayyaTheme.swift, new TayyaComponents.swift; appearance, contrast and accessibility tests |
| StudioLibrary and document cards | LibraryStore, LibraryScreen, NotebookCover | LibraryScreen.swift; real creation/import/search/sections/trash/backup tests |
| StudioWorkspace five-tool dock, contextual rails, Focus | DocumentScreen, PDFWorkspace, NativePDF, ResizingPDFView | PDFWorkspace.swift, WorkspaceTools.swift; native viewport, ink commit and UI regression suites |
| Studio Notes presentation | MarginPages, MarginPagesView, MarginNotebook | MarginPane.swift and presentation only; margin round-trip, flush failure, rotation/split UI tests |
| Studio recording cards and marker controls | PageAudio / RecordingActivity / AudioLink / AVFoundation | PageAudio.swift, AudioLinks.swift, RecordingStrip.swift; permission, interruption, playback, metadata and corruption tests |
| Studio presets and thumbnails | Real document pages / native ink bindings | New small preset and thumbnail helpers; persistence, cache identity/invalidation and actual PDF tests |
| Studio study/navigation actions | Existing Flashcards, templates, export and Office pipeline | Reuse existing routes; never substitute simulated models |

## Invariants

Keep version 0.6.0, build 13, bundle ID com.ahmadalawi.hashiya, iOS 17 and both device families. Keep existing file names, data keys, notebook UUIDs, recordings, legacy margins, PencilKit coordinates and native undo behavior. Rename display copy to Notes / الملاحظات without renaming storage or accessibility identifiers. New metadata must be optional, recoverable and backward compatible. Damaged existing data must never silently become an empty writable store.

Retain the document, Notes and audio state objects across tool, Focus, split and orientation changes. Retain the proven InkToolbarScrollView implementation. Color/tool changes must not reset zoom or reading position. Audio page changes create a marker within the same recording; recording never opens Notes. Studio's simulated recording and fixture documents are excluded from production.

## Verification and delivery

Use Linux for Python/static checks and macOS Actions for Xcode/XCTest/XCUITest/Maestro and actual screenshots. Add focused failing tests before functional fixes; preserve every original test and success criterion. Do not repeat the green baseline or run full release gates for documentation. Diagnose native failures from their actual logs/xcresult before another run.

After component and data-compatibility gates, run all original and new production tests on one final SHA, capture real integrated iPhone/iPad screens, then build the real unsigned app with the existing native Office packaging path. Verify arm64, resources, Info.plist, ZIP and SHA256. No final IPA claim while an obligatory gate is unresolved. Simulator audio fixtures cannot establish physical microphone capture or physical-device Office conversion; report those limits explicitly. No merge or Apple upload is authorized.
