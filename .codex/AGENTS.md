# SwiftMachine Agent Guide

SwiftMachine is a macOS SwiftUI app for visually authoring Mealy state machines and exporting them into spec files that AI coding agents can implement.

The repository currently contains:
- an Xcode app project with the `SwiftMachine` scheme
- a single app target in `SwiftMachine/`
- a Swift Testing test target in `SwiftMachineTests/`

This file should stay stable and structural.

## Project Map

### Current Bootstrap

- `SwiftMachine/SwiftMachineApp.swift`
  - app entry point
  - currently launches a single root view
- `SwiftMachine/ContentView.swift`
  - current placeholder root UI
- `SwiftMachineTests/SwiftMachineTests.swift`
  - Swift Testing scaffold
- `SwiftMachine.xcodeproj/`
  - project configuration and schemes

### Preferred Growth Path

As the app grows, prefer this shape instead of letting the template expand in place:

- `SwiftMachine/App/`
  - app entry, composition root, DI, app-wide coordination
- `SwiftMachine/Features/`
  - one feature per sub-folder. A feature is a `Views` sub-folder and a `StateMachine` sub-folder.
- `SwiftMachine/Domain/`
  - application shared business model, inert data structures
- `SwiftMachine/Infrastructure/`
  - file IO, persistence, import/export codecs, document integration
- `SwiftMachine/UIComponents/`
  - reusable SwiftUI and AppKit-backed building blocks

Do not create all of these folders preemptively. Introduce structure only when the task needs it.

## Coding Guidance

- Favor functional core / imperative shell.
- Keep Mealy semantics independent from SwiftUI.
- Prefer value types in the domain and export layers.
- Use reference types only where UI coordination or framework integration requires them.
- Keep dependencies narrow and feature-scoped.
- Prefer composition over inheritance.
- Keep functions and files small enough to reason about locally.
- Avoid burying business rules inside view modifiers, gestures, or ad hoc bindings.
- Remove dead code and placeholder wiring when touching an area for real implementation.

For macOS-specific work:
- prefer `NavigationSplitView`, inspector patterns, commands, and focus management when they fit
- account for keyboard navigation, accessibility, and pointer behavior
- treat undo and redo as first-class behavior in editing flows

Use the Cupertino MCP server and the Sosumi MCP server when you need to access official documention and guidance for the Swift language.

## Testing Guidance

- Use Swift Testing.
- Prefer focused tests over broad integration tests while the architecture is still moving.
- Add tests whenever machine semantics, validation rules, or export grammar changes.
- Prefer text-based golden assertions for exported specs.
- Keep editor interaction tests narrow and deterministic.

Useful test targets as the app grows:
- domain reducer or transformation tests
- validation tests for invalid or ambiguous machines
- export serialization tests
- import or round-trip tests when parsing is introduced

## Validation

Prefer building and testing with the macOS destination.

- Project: `SwiftMachine.xcodeproj`
- Main app scheme: `SwiftMachine`
- Build:
  - `xcodebuild -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS' build`
- Test:
  - `xcodebuild -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS' test`

If XcodeBuildMCP supports the current workflow, prefer it. Otherwise use `xcodebuild` directly.

## Skills To Prefer When Relevant

- `swift-functional-architecture`
- `swift-concurrency`
- `swift-testing-expert`
- `swiftui-expert`
- `git-user`

If this guide and the code disagree, trust the code, then update this guide so the next session starts from the correct model.
