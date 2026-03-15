# SwiftMachine Agent Guide

SwiftMachine is a macOS SwiftUI app for designing state machine definitions.

The repository contains:
- an Xcode app project with the `SwiftMachine` scheme
- a single app target in `SwiftMachine/`
- a Swift Testing test target in `SwiftMachineTests/`

This file should stay stable and structural.

## Read Order For A Fresh Session

1. Read `SwiftMachine/App/SwiftMachineApp.swift`.
2. Read `SwiftMachine/Features/StateMachineEditor/Views/SwiftMachineRootView.swift`.
3. Read `SwiftMachine/Features/StateMachineEditor/Runtime/SwiftMachineStore.swift`.
4. Read `SwiftMachine/Features/StateMachineEditor/Runtime/SwiftMachineStateMachine.swift`.
5. Read `SwiftMachine/Domain/StateMachineDefinition.swift`.
6. Then move to the feature or domain file directly related to the task.

## Project Map

### App Boot And Shell

- `SwiftMachine/App/`
  - app entry point and window configuration
  - injects a shared `SwiftMachineStore`

### State Machine Editor

- `SwiftMachine/Features/StateMachineEditor/Views/`
  - setup wizard, editor shell, canvas, and toolbox
- `SwiftMachine/Features/StateMachineEditor/Runtime/`
  - store, reducer, and runtime types for the editor flow

### Domain

- `SwiftMachine/Domain/`
  - state machine model, lifecycle helpers, and validation
  - this layer should stay pure and independent from SwiftUI

### Tests

- `SwiftMachineTests/`
  - Swift Testing coverage for validation, lifecycle helpers, reducer transitions, and store behavior

## Coding Guidance

- Favor functional core / imperative shell.
- Keep reducer and domain logic independent from SwiftUI.
- Prefer value types in the domain layer.
- Use reference types only where UI coordination or framework integration requires them.
- Keep dependencies narrow and feature-scoped.
- Prefer composition over inheritance.
- Keep functions and files small enough to reason about locally.
- Avoid burying business rules inside view modifiers, gestures, or ad hoc bindings.
- Remove dead code and placeholder wiring when touching an area for real implementation.
- Keep shared layout numbers in `SwiftMachineShellMetrics.swift` instead of scattering magic numbers through views.

For macOS-specific work:
- prefer `NavigationSplitView`, inspector patterns, commands, and focus management when they fit
- account for keyboard navigation, accessibility, and pointer behavior
- treat undo and redo as first-class behavior in editing flows

Use the Cupertino MCP server and the Sosumi MCP server when you need to access official documentation and guidance for the Swift language.

## Runtime Architecture

### Editor Flow

- `SwiftMachineApp` creates the shared store.
- `SwiftMachineRootView` routes between the setup wizard and the editor shell.
- Views dispatch `SwiftMachineEvent`.
- `SwiftMachineStateMachine.reduce` returns a `Transition`.
- `SwiftMachineStore.send(_:)` applies the next state.
- `.addNewTransition` is intentionally not implemented yet, and the toolbox action is disabled.

### Domain Flow

- `StateMachineDefinition` is the root aggregate.
- `StateMachineDefinition+Lifecycle` owns builder-style editor mutations.
- `StateMachineDefinition+Validation` owns invariants and reference checks.
- Domain types should remain usable without UI or framework concerns.

## How To Route A Change

### UI-Only Change

- Start in the relevant file under `SwiftMachine/Features/StateMachineEditor/Views/`.
- Check `SwiftMachineShellMetrics.swift` before adding new layout constants.
- Preserve the current visual language unless the task explicitly changes design.

### Editor Behavior Change

- Start in `SwiftMachineStore.swift` and `SwiftMachineStateMachine.swift`.
- Then inspect the view that dispatches the event.
- Add or update focused tests in `SwiftMachineStateMachineTests.swift` or `SwiftMachineStoreTests.swift`.

### Domain Or Validation Change

- Start in `StateMachineDefinition.swift` and its lifecycle or validation extensions.
- Keep the change pure and value-oriented.
- Add or update focused tests in `StateMachineDefinitionTests.swift` or `StateMachineDefinitionLifecycleTests.swift`.

## Testing Guidance

- Use Swift Testing.
- Prefer focused tests over broad integration tests.
- Add or update tests whenever reducer logic, validation rules, or builder helpers change.
- Prefer targeted validation while iterating, then broaden if needed.

## Validation

### App

- Prefer XcodeBuildMCP when it matches the workflow.
- Project: `SwiftMachine.xcodeproj`
- Main app scheme: `SwiftMachine`
- Build:
  - `xcodebuild -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS' build`
- Test:
  - `xcodebuild -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS' test`

## Skills To Prefer When Relevant

- `swift-functional-architecture`
- `swift-concurrency`
- `swift-testing-expert`
- `swiftui-expert`
- `git-user`

If this guide and the code disagree, trust the code, then update this guide so the next session starts from the correct model.
