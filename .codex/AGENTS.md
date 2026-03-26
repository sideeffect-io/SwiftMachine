# SwiftMachine Agent Guide

SwiftMachine is a macOS SwiftUI app for visually designing state machines and exporting them as stable Markdown specs.

The repository currently contains:
- one Xcode app target in `SwiftMachine/`
- one Swift Testing target in `SwiftMachineTests/`
- a feature-split editor built from small observable stores wired through a shared composition root

This guide should stay structural and reflect the code as it exists now.

## Read Order For A Fresh Session

1. Read `README.md`.
2. Read `SwiftMachine/App/SwiftMachineApp.swift`.
3. Read `SwiftMachine/App/DI/AppCompositionRoot.swift`.
4. Read `SwiftMachine/App/DI/CurrentStateMachineDefinitionService.swift`.
5. Read `SwiftMachine/Features/EditorCanvas/Views/SwiftMachineRootView.swift`.
6. Read `SwiftMachine/Features/EditorCanvas/Views/SwiftMachineCanvasView.swift`.
7. Read `SwiftMachine/Features/EditorCanvas/Runtime/EditorCanvasStore.swift`.
8. Read `SwiftMachine/App/DI/EditorCanvasEventExecutor.swift`.
9. Read `SwiftMachine/Domain/StateMachineDefinition.swift`.
10. Read `SwiftMachine/Domain/StateMachineDefinition+Lifecycle.swift`.
11. Read `SwiftMachine/Domain/StateMachineDefinition+Validation.swift`.
12. Read `SwiftMachine/Domain/StateMachineEditorDocument.swift`.
13. Then move directly to the feature, DI file, or domain type related to the task.

## Project Map

### App Boot And Dependency Wiring

- `SwiftMachine/App/SwiftMachineApp.swift`
  - app entry point and window sizing
  - injects the shared `AppCompositionRoot`
- `SwiftMachine/App/DI/`
  - environment-backed store factories
  - live DI wiring for each feature
  - shared service and command executors used to coordinate features
- `SwiftMachine/App/DI/StoreTools.swift`
  - `StartableStore` and `WithViewStore`
  - most feature views are created through this pattern

### Shared Definition Service

- `SwiftMachine/App/DI/CurrentStateMachineDefinitionService.swift`
  - the single source of truth for the current `StateMachineDefinition`
  - publishes snapshots with a monotonically increasing revision
  - feature stores observe or mutate through this service rather than talking to each other directly
- `SwiftMachine/App/DI/StoreFactoryMutationSupport.swift`
  - shared helper for applying definition mutations
- `SwiftMachine/App/DI/EditorCanvasEventExecutor.swift`
  - command bridge back into `EditorCanvasStore`
  - used by palettes, inspectors, and transition composition to drive selection and prompt state

### Root Editor Shell

- `SwiftMachine/Features/EditorCanvas/Views/SwiftMachineRootView.swift`
  - top-level root view
- `SwiftMachine/Features/EditorCanvas/Views/SwiftMachineCanvasView.swift`
  - switches between wizard and editor phases
  - owns the three-pane shell: toolbox, graph canvas, inspector
- `SwiftMachine/Features/EditorCanvas/Runtime/EditorCanvasStore.swift`
  - orchestrates phase, selection, graph layout, connection drag state, and transition prompt presentation
  - reconciles observed definition snapshots into editor presentation state
- `SwiftMachine/Features/EditorCanvas/Views/`
  - graph rendering, shell composition, and canvas interaction support

### Feature Stores

- `SwiftMachine/Features/SwiftMachineWizard/`
  - bootstraps the initial machine and first state
- `SwiftMachine/Features/StatePalette/`
  - reusable state library and creation actions
- `SwiftMachine/Features/EventPalette/`
  - reusable event library and creation actions
- `SwiftMachine/Features/TypePalette/`
  - reusable payload type library
- `SwiftMachine/Features/StateInspector/`
  - selected state editing
- `SwiftMachine/Features/EventInspector/`
  - selected event editing
- `SwiftMachine/Features/TypeInspector/`
  - selected type editing
- `SwiftMachine/Features/TransitionComposer/`
  - creates transitions after a canvas drag
  - can bind an existing event or create a new one
- `SwiftMachine/Features/TransitionInspector/`
  - edits transition semantics after selection
- `SwiftMachine/Features/StateMachineExport/`
  - renders deterministic Markdown preview
  - saves Markdown to disk through `NSSavePanel`

### Shared Views

- `SwiftMachine/Features/SharedViews/`
  - shell metrics
  - reusable property editors and shared editor UI
  - transition target-state creation editing helpers

### Domain

- `SwiftMachine/Domain/`
  - pure state machine model and lifecycle operations
  - validation rules and editor geometry/layout
  - editor document representation
  - Markdown export rendering
- key types:
  - `StateMachineDefinition`
  - `StateMachineEditorDocument`
  - `StateMachineEditorLayout`
  - `EditorCanvasPresentationState`
  - `TransitionDefinition`
  - `PayloadTypeDefinition`
  - `StateMachineExportRenderer`

### Tests

- `SwiftMachineTests/`
  - focused Swift Testing coverage by feature and domain type
  - current suites include wizard, canvas, palettes, inspectors, transition composition, export, layout, document migration, and domain validation

## Architecture Notes

### Current Shape

- The app is composed from small feature stores with narrow responsibilities.
- Cross-feature coordination happens through:
  - `CurrentStateMachineDefinitionService` for shared definition state
  - `EditorCanvasCommand` for selection and prompt coordination
- `EditorCanvasStore` is the shell coordinator, not the owner of all editing rules.

### Data Flow

- Views create stores through environment-backed factories in `AppCompositionRoot`.
- Stores call `start()` through `WithViewStore`.
- Feature stores observe the shared definition snapshot when they need live state.
- Feature stores mutate the definition through DI closures backed by `CurrentStateMachineDefinitionService`.
- `EditorCanvasStore` reconciles definition snapshots into layout, selection, and prompt state.
- Export rendering is derived from the current definition plus snapshot revision.

### Domain Boundaries

- Keep `SwiftMachine/Domain` pure and framework-independent.
- `StateMachineDefinition+Lifecycle` owns builder-style mutations.
- `StateMachineDefinition+Validation` owns invariants and reference checks.
- `StateMachineEditorDocument` owns codable editor persistence shape and legacy migration for stored transition positions.
- `StateMachineEditorLayout` and geometry helpers own editor-only positioning logic.
- `StateMachineExportRenderer` owns deterministic Markdown generation.

## How To Route A Change

### App Wiring Or Dependency Injection

- Start in `SwiftMachine/App/DI/AppCompositionRoot.swift`.
- Then inspect the specific `*StoreDI.swift` file for the feature.
- Keep factories small and pass behavior in as explicit executors or closures.

### Wizard Flow

- Start in `SwiftMachine/Features/SwiftMachineWizard/Runtime/SwiftMachineWizardStore.swift`.
- Then inspect `SwiftMachineWizardView.swift`.
- If initial machine creation changes, verify the service-backed DI file too.

### Graph Or Selection Behavior

- Start in `SwiftMachine/Features/EditorCanvas/Runtime/EditorCanvasStore.swift`.
- Then inspect:
  - `SwiftMachine/App/DI/EditorCanvasEventExecutor.swift`
  - the relevant view under `SwiftMachine/Features/EditorCanvas/Views/`
- Add or update `EditorCanvasStoreTests.swift` or `EditorCanvasPresentationStateTests.swift`.

### Palette Behavior

- Start in the relevant runtime file under:
  - `SwiftMachine/Features/StatePalette/Runtime/`
  - `SwiftMachine/Features/EventPalette/Runtime/`
  - `SwiftMachine/Features/TypePalette/Runtime/`
- Then inspect the matching view and DI file.
- Add or update the corresponding `*PaletteStoreTests.swift`.

### Inspector Behavior

- Start in the relevant runtime file under:
  - `SwiftMachine/Features/StateInspector/Runtime/`
  - `SwiftMachine/Features/EventInspector/Runtime/`
  - `SwiftMachine/Features/TypeInspector/Runtime/`
  - `SwiftMachine/Features/TransitionInspector/Runtime/`
- Then inspect the matching view dependency file.
- Add or update the corresponding `*InspectorStoreTests.swift`.

### Transition Creation Flow

- Start in `SwiftMachine/Features/TransitionComposer/Runtime/TransitionComposerStore.swift`.
- Then inspect:
  - `SwiftMachine/App/DI/TransitionComposerStoreDI.swift`
  - `SwiftMachine/App/DI/EditorCanvasEventExecutor.swift`
  - `SwiftMachine/Features/EditorCanvas/Runtime/EditorCanvasStore.swift`
- Add or update `TransitionComposerStoreTests.swift`.

### Export Behavior

- Start in `SwiftMachine/Domain/StateMachineExportRenderer.swift`.
- Then inspect `SwiftMachine/Features/StateMachineExport/Runtime/StateMachineExportStore.swift`.
- Keep Markdown output deterministic and reviewable.
- Add or update:
  - `StateMachineExportRendererTests.swift`
  - `StateMachineExportStoreTests.swift`

### Domain Or Validation Change

- Start in `StateMachineDefinition.swift` and its lifecycle or validation extensions.
- Keep the change pure and value-oriented.
- If persistence shape changes, also inspect `StateMachineEditorDocument.swift`.
- Add or update the most focused tests in:
  - `StateMachineDefinitionTests.swift`
  - `StateMachineDefinitionLifecycleTests.swift`
  - `StateMachineEditorDocumentTests.swift`

## Coding Guidance

- Favor functional core / imperative shell.
- Keep domain and reducer logic independent from SwiftUI and AppKit.
- Prefer value types in the domain layer.
- Use reference types for observable stores, services, and UI coordination only.
- Keep store effects explicit through small executor types or DI closures.
- Prefer adding a focused feature store over growing `EditorCanvasStore` into a new monolith.
- Do not bypass `CurrentStateMachineDefinitionService` for shared definition changes.
- Do not hide business rules in view modifiers or ad hoc bindings when they belong in the store or domain.
- Keep shared shell sizing and spacing in `SwiftMachineShellMetrics.swift`.
- Preserve deterministic export output and revision-driven filenames.

For macOS-specific work:
- prefer split views, inspector patterns, keyboard-friendly flows, and pointer-aware interactions
- treat save/export UX as desktop-native behavior
- account for accessibility and selection feedback in graph editing flows

Use the Cupertino MCP server and the Sosumi MCP server when you need official Apple or Swift documentation.

## Testing Guidance

- Use Swift Testing.
- Prefer focused store and domain tests over broad UI-heavy tests.
- Add or update tests whenever you change:
  - snapshot reconciliation
  - definition mutations
  - selection routing
  - transition creation
  - export rendering
  - document coding or migration behavior
- When touching a feature store, check whether a same-named test file already exists before creating a new suite.

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
- `mobile-ios-design`
- `git-user`

If this guide and the code disagree, trust the code first, then update this guide so the next session starts from the correct model.
