# SwiftMachine Agent Guide

SwiftMachine is a macOS SwiftUI app for designing state machine definitions. The current codebase focuses on an in-memory editor shell, a reducer-style runtime, and a pure domain model. This file should stay stable and structural.

## Current Project Structure

- `SwiftMachine.xcodeproj/`
  - Xcode project and the `SwiftMachine` scheme.
- `SwiftMachine/App/`
  - App entry point and composition root.
  - `SwiftMachineApp.swift` creates the shared `SwiftMachineStore`, injects it into the environment, and configures the window shell.
- `SwiftMachine/Domain/`
  - Pure business model and validation layer.
  - `StateMachineDefinition.swift` is the root aggregate.
  - `StateMachineDefinition+Lifecycle.swift` contains editor-oriented builders and mutations such as `makeNew()`, `addingState()`, and `addingEvent()`.
  - `StateMachineDefinition+Validation.swift` contains invariants and `ValidationError`.
  - Supporting value types live alongside it: `StateDefinition`, `EventDefinition`, `TransitionDefinition`, `PropertyDefinition`, `PropertyType`, `GuardReference`, `EffectReference`, and `LiteralValue`.
- `SwiftMachine/Features/StateMachineEditor/Runtime/`
  - Reducer-style editor runtime.
  - `SwiftMachineStore.swift` is the `@Observable` store with `send(_:)`.
  - `SwiftMachineStateMachine.swift` contains the reducer from `SwiftMachineState` and `SwiftMachineEvent` to `Transition`.
  - `SwiftMachineState.swift`, `SwiftMachineEvent.swift`, and `SwiftMachineEffect.swift` define runtime types.
- `SwiftMachine/Features/StateMachineEditor/Views/`
  - SwiftUI presentation layer for the editor.
  - `SwiftMachineRootView.swift` chooses between the setup wizard and the editor shell.
  - `SwiftMachineCanvasView.swift` is the main canvas and also contains several private wizard and canvas subviews in the same file.
  - `SwiftMachineToolboxView.swift` is the left sidebar with editor actions and summary cards.
  - `SwiftMachineShellMetrics.swift` centralizes shell layout constants.
- `SwiftMachine/Assets.xcassets/`
  - App assets and icon catalog.
- `SwiftMachineTests/`
  - Swift Testing target organized by production layer.
  - `StateMachineDefinitionTests.swift` covers validation and model invariants.
  - `StateMachineDefinitionLifecycleTests.swift` covers builder and editor lifecycle helpers.
  - `SwiftMachineStateMachineTests.swift` covers reducer transitions.
  - `SwiftMachineStoreTests.swift` covers observable store behavior.

## Agent Discovery Workflow

Use this order when you need to orient yourself quickly:

1. Start with `SwiftMachine/App/SwiftMachineApp.swift` to see the app boundary, shared store, and window setup.
2. Read `SwiftMachine/Features/StateMachineEditor/Views/SwiftMachineRootView.swift` to understand top-level screen composition.
3. For behavior changes, inspect runtime files in this order:
   - `SwiftMachineStore.swift`
   - `SwiftMachineState.swift`
   - `SwiftMachineEvent.swift`
   - `SwiftMachineStateMachine.swift`
4. For model or validation work, inspect files in this order:
   - `StateMachineDefinition.swift`
   - `StateMachineDefinition+Lifecycle.swift`
   - `StateMachineDefinition+Validation.swift`
   - related domain types under `SwiftMachine/Domain/`
5. Before changing UI, search inside `SwiftMachineCanvasView.swift` and `SwiftMachineToolboxView.swift` for private nested views so you extend existing composition instead of duplicating it.
6. Update the matching test file whenever you change domain rules, reducer transitions, or store behavior.

Useful discovery commands:

- List schemes:
  - `xcodebuild -list -project SwiftMachine.xcodeproj`
- Search the main architecture quickly:
  - `rg 'SwiftMachineStore|SwiftMachineStateMachine|StateMachineDefinition' SwiftMachine SwiftMachineTests`
- Inspect the repository shape:
  - `find SwiftMachine SwiftMachineTests -maxdepth 4 -type f | sort`

## Growth Guidance

As the app grows, prefer this structure instead of scattering cross-cutting code:

- `SwiftMachine/App/`
  - app entry, composition root, DI, app-wide coordination
- `SwiftMachine/Features/`
  - one feature per sub-folder, with view and runtime files kept close to each other
- `SwiftMachine/Domain/`
  - application-wide business model and inert data structures
- `SwiftMachine/Infrastructure/`
  - file IO, persistence, import or export codecs, and document integration when those features exist
- `SwiftMachine/UIComponents/`
  - reusable SwiftUI or AppKit-backed building blocks only when reuse is real

Do not create folders preemptively. Introduce structure only when the task needs it.

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
- `SwiftMachineStateMachine.reduce` returns `Transition` with `effects`, but effects are not used yet.
- `.addNewTransition` is currently a no-op in the reducer and the corresponding toolbox action is disabled.
- Keep shared layout numbers in `SwiftMachineShellMetrics.swift` instead of scattering magic numbers through views.

For macOS-specific work:
- prefer `NavigationSplitView`, inspector patterns, commands, and focus management when they fit
- account for keyboard navigation, accessibility, and pointer behavior
- treat undo and redo as first-class behavior in editing flows

Use the Cupertino MCP server and the Sosumi MCP server when you need to access official documention and guidance for the Swift language.

## Testing Guidance

- Use Swift Testing.
- Prefer focused tests over broad integration tests while the architecture is still moving.
- Add tests whenever machine semantics, validation rules, or export grammar changes.
- Current tests already cover domain validation, lifecycle helpers, reducer transitions, and store behavior.
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
- List schemes:
  - `xcodebuild -list -project SwiftMachine.xcodeproj`
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
