# SwiftMachine Agent Guide

## Project Summary
- `SwiftMachine` is a macOS SwiftUI app for drafting and editing state machine definitions in memory.
- The repository is an Xcode project, not a Swift package. Use `SwiftMachine.xcodeproj`.
- Main scheme: `SwiftMachine`
- Targets: `SwiftMachine`, `SwiftMachineTests`
- Platform: macOS (`SUPPORTED_PLATFORMS = macosx`)

## Project Structure
- `SwiftMachine/App/`
  - App entry point.
  - `SwiftMachineApp.swift` creates the shared `SwiftMachineStore`, injects it into the environment, and configures the main window.
- `SwiftMachine/Domain/`
  - Pure model layer for state machine definitions.
  - `StateMachineDefinition.swift` is the root aggregate.
  - `StateMachineDefinition+Lifecycle.swift` contains editor-oriented builders and mutations such as `makeNew()`, `addingState()`, and `addingEvent()`.
  - `StateMachineDefinition+Validation.swift` contains invariants and `ValidationError`.
  - Supporting value types live alongside it: `StateDefinition`, `EventDefinition`, `TransitionDefinition`, `PropertyDefinition`, `PropertyType`, `GuardReference`, `EffectReference`, and `LiteralValue`.
- `SwiftMachine/Features/StateMachineEditor/Runtime/`
  - Reducer-style editor runtime.
  - `SwiftMachineStore.swift` is the observable store with `send(_:)`.
  - `SwiftMachineStateMachine.swift` contains the reducer from `SwiftMachineState` and `SwiftMachineEvent` to `Transition`.
  - `SwiftMachineState.swift`, `SwiftMachineEvent.swift`, and `SwiftMachineEffect.swift` define runtime types.
- `SwiftMachine/Features/StateMachineEditor/Views/`
  - SwiftUI presentation layer for the editor.
  - `SwiftMachineRootView.swift` decides whether the app shows the setup wizard or the editor shell.
  - `SwiftMachineCanvasView.swift` is the main canvas and also contains several private wizard/canvas subviews in the same file.
  - `SwiftMachineToolboxView.swift` is the left sidebar with editor actions and summary cards.
  - `SwiftMachineShellMetrics.swift` centralizes layout constants used across the shell.
- `SwiftMachineTests/`
  - Tests are organized by production layer.
  - `StateMachineDefinitionTests.swift` covers validation and model invariants.
  - `StateMachineDefinitionLifecycleTests.swift` covers builder/editor lifecycle helpers.
  - `SwiftMachineStateMachineTests.swift` covers reducer transitions.
  - `SwiftMachineStoreTests.swift` covers store publishing and state updates.

## Agent Discovery Workflow
1. Start with `SwiftMachine/App/SwiftMachineApp.swift` to see the app boundary, the shared store, and window setup.
2. Read `SwiftMachine/Features/StateMachineEditor/Views/SwiftMachineRootView.swift` to understand top-level screen composition.
3. For behavior changes, inspect runtime files in this order:
   - `SwiftMachineStore.swift`
   - `SwiftMachineState.swift`
   - `SwiftMachineEvent.swift`
   - `SwiftMachineStateMachine.swift`
4. For domain or validation work, inspect files in this order:
   - `StateMachineDefinition.swift`
   - `StateMachineDefinition+Lifecycle.swift`
   - `StateMachineDefinition+Validation.swift`
   - related domain types under `SwiftMachine/Domain/`
5. Before changing UI, search inside `SwiftMachineCanvasView.swift` and `SwiftMachineToolboxView.swift` for private nested views so you extend existing composition instead of duplicating it.
6. Update the matching test file whenever you change domain rules, reducer transitions, or store behavior.

## Practical Commands
- List schemes:
  - `xcodebuild -list -project SwiftMachine.xcodeproj`
- Run tests:
  - `xcodebuild test -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS'`
- Search the main architecture quickly:
  - `rg 'SwiftMachineStore|SwiftMachineStateMachine|StateMachineDefinition' SwiftMachine SwiftMachineTests`
- Inspect the repo shape:
  - `find SwiftMachine SwiftMachineTests -maxdepth 4 -type f | sort`

## Project Conventions
- The app uses a small reducer/store architecture:
  - UI dispatches `SwiftMachineEvent`
  - `SwiftMachineStateMachine.reduce` returns a `Transition`
  - `SwiftMachineStore` applies the next state
- Domain models are value types and should remain easy to validate and test in isolation.
- Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`, `#require`) rather than XCTest.
- The app currently works entirely in memory. There is no persistence, networking, or external service layer yet.
- Transition creation is not implemented yet:
  - `.addNewTransition` is currently a no-op in the reducer
  - the corresponding toolbox action is disabled in the UI
- Many UI details are intentionally centralized in `SwiftMachineShellMetrics.swift`; prefer extending those constants instead of scattering magic numbers.
