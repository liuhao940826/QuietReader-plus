# Pagination Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign novel paging so the menu bar keeps a fixed display width while page content avoids artificial blank padding and empty-looking transitions.

**Architecture:** Keep the menu bar label width fixed in SwiftUI, but simplify paging in `PageSlicer` to use a fixed character budget with natural breakpoints. Remove any padding-based alignment from page content so UI width and content slicing are independent concerns.

**Tech Stack:** Swift, SwiftUI, AppKit, Swift Package Manager

---

### Task 1: Replace padded page slicing with fixed-budget natural slicing

**Files:**
- Modify: `MenuReader/Services.swift`

**Step 1: Update the page slicing rules**

- Keep a fixed per-page character budget.
- Normalize line endings and tabs.
- Collapse repeated whitespace inside a paragraph.
- Prefer cutting at: paragraph boundary, sentence punctuation, clause punctuation, whitespace.
- Only hard-cut when no good breakpoint exists.
- Do not pad output with spaces.
- Do not emit empty pages.

**Step 2: Preserve simple API surface**

- Keep `PageSlicer.slice(content:) -> [String]` unchanged so callers do not need redesign.

**Step 3: Run focused build verification**

Run: `swift build`
Expected: PASS

### Task 2: Keep menu bar width fixed but decouple from page filling

**Files:**
- Modify: `MenuReader/MenuReaderApp.swift`

**Step 1: Verify label width remains fixed**

- Keep the menu bar text container width fixed.
- Do not add string padding or visual filler to page text.

**Step 2: Ensure hidden mode remains icon-only**

- Preserve the current label behavior: text-only when visible, icon-only when hidden.

**Step 3: Run focused build verification**

Run: `swift build`
Expected: PASS

### Task 3: Validate real packaging path after paging redesign

**Files:**
- No source changes required if earlier tasks pass

**Step 1: Run packaging script**

Run: `./build.sh`
Expected: PASS and `build/MenuReader.app` regenerated

**Step 2: Manual behavior checklist**

- Import a TXT with mixed short/long paragraphs
- Flip pages forward/backward
- Confirm there are no space-padded near-empty pages
- Confirm menu bar width still appears fixed

### Task 4: Commit

**Step 1: Commit only intended source changes**

```bash
git add MenuReader/Services.swift MenuReader/MenuReaderApp.swift docs/plans/2026-05-24-pagination-redesign.md
git commit -m "refine pagination behavior"
```
