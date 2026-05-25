# UI App Collaboration Playbook

## Core Flow

1. Define the product skeleton first.
- Clarify the core scene.
- Identify the 3 most frequent actions.
- Split high-frequency entry points from management functions.
- Decide the information hierarchy before coding.

2. Build a usable first version before polishing.
- Get the main path working end to end.
- Ignore icon, spacing, checkmark, and alignment polish at this stage.
- Goal: verify interaction flow, not visual quality.

3. Refactor structure as soon as the main path works.
- Separate state, logic, and UI.
- Do not wait until features accumulate.
- This is the main step that prevents a UI project from turning into a mess.

4. Polish high-frequency UI first.
- Prioritize the main display area.
- Then the primary menu or toolbar.
- Then high-frequency selectors.
- Leave secondary management screens for later.

5. Do visual consistency work last.
- Align icons, checkmarks, spacing, and status labels only after interaction is stable.
- Prefer framework-native or system-native components over hand-built visual hacks.

6. Test logic automatically, validate UI manually.
- Automate pure logic such as pagination, state restore, persistence, and switching.
- Manually verify visual quality, menu behavior, spacing, and overall feel.

7. Solve one layer of problems per iteration.
- One round for interaction design.
- One round for feature completion.
- One round for structural refactor.
- One round for UI polish.
- One round for testing and packaging.

## Lessons From MenuReader

- The main inefficiency came from mixing feature design, interaction design, structural changes, and visual polish in the same iteration.
- Once the main path was stable, structural refactoring immediately improved speed and confidence.
- Native components usually beat hand-built UI tricks, especially for menu selection and state display.
- Pagination quality matters more than over-optimizing visual tricks for fixed-width text.

## Collaboration Template

1. User describes the target scenario.
2. AI proposes a minimal interaction skeleton.
3. User approves the skeleton.
4. AI implements a low-fidelity but usable version.
5. AI performs an early structural refactor.
6. User and AI polish the highest-frequency UI.
7. AI verifies build and packaging.
8. AI adds tests for logic-heavy parts when the product shape is stable.

## Working Principle

First make it correct, then make it smooth, then make it beautiful.
