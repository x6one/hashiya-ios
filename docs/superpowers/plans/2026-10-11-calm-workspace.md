# Calm workspace Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or bounded parallel workers; user authorized autonomous implementation.

**Goal:** Implement the approved Tayya calm workspace, isolate recording, and remove unsupported language clutter.

**Architecture:** Keep LibraryStore/PDFWorkspace/MarginPages storage contracts intact. Independently update the library/theme and document/audio surfaces, then integrate margins and native acceptance tests centrally.

**Tech Stack:** SwiftUI, PDFKit, PencilKit, AVFoundation, Vision, XCTest/XCUITest, Maestro.

**Spec:** ../specs/2026-10-11-calm-workspace-design.md

## Global Constraints
- iOS 17+, Arabic RTL, iPhone/iPad; no new paid dependencies or user-data deletion.
- Keep existing file formats, sidecars, recoverable page deletion and accessibility identifiers.
- Candidate 0.5.0 (11); Apple submission stays untouched until native checks pass.

## Review Focus
- Short landscape windows must reserve drawing space and keep navigation reachable.
- Permission grant/denial must not change margin layout or duplicate recording starts.
- Existing page recording folders remain discoverable after unified audio entry.
- Moved/trash files and demo entry must remain reachable through phone/tablet navigation.
- Unsupported OCR languages must not appear; no supported-language fallback that falsely labels Arabic.

## Task 1: Library and visual foundation
- [ ] Own App/LibraryScreen.swift, App/TayyaTheme.swift; add thumbnail/support views as needed.
- [ ] Add real PDF thumbnails, compact cards, calm colors, phone bottom destinations, tablet sidebar, settings/backup/demo access and recent/resume.
- [ ] Preserve IDs and data contracts; verify build and native library lifecycle/navigation.

## Task 2: Document controls, audio isolation and OCR capability
- [ ] Own App/PDFWorkspace.swift, App/WorkspaceTools.swift, App/AudioLinks.swift, App/PageAudio.swift, App/LibrarySearch.swift.
- [ ] Trace recording coupling, remove split mutation, guard repeated permission-start requests, make recorder/history coherent while retaining old page recordings.
- [ ] Compact document toolbar/navigation; list only supported OCR choices. Preserve known IDs.
- [ ] Native regression test: record with margin closed, stop, relaunch, deny microphone, write with margin closed/open unchanged.

## Task 3: Margin controls and integration
- [ ] Own App/MarginPane.swift, UITests/LaunchTests.swift, project.yml, App/DemoLibrary.swift and status docs.
- [ ] Simplify margins without dropping add/delete/recover; move optional linking to page management.
- [ ] Adapt tests for deliberate navigation changes; add no-coupling audio and readable navigation/layout assertions.
- [ ] Run full existing XCTest, XCUITest and Maestro on both device families at the same commit; inspect screenshots, fix failures, build candidate IPA only after passing.

## Completion
- [ ] Independent review of combined diff; reconcile contract/layout/persistence risks.
- [ ] Store changes in external GitHub branch/PR; report exact checks and remaining blockers truthfully.
