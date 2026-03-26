# SwiftMachine

SwiftMachine is a macOS SwiftUI app for designing state machines visually and exporting them as stable Markdown specs.

The project is currently at the MVP stage: the core modeling flow works end-to-end, with a setup wizard, a diagram-first editor, semantic inspectors, validation rules, and AI-friendly export.

## MVP Scope

SwiftMachine currently lets you:

- create a machine from a guided wizard
- define the machine name and initial state
- add reusable states, events, and payload types
- model payloads with primitives, structs, and enums
- place states on a graph canvas and reposition them freely
- create transitions directly on the canvas
- configure transition routing, target-state assignments, guards, and effects
- validate the machine structure and payload references as you edit
- export the current machine as deterministic Markdown

The current export is intended to be easy to read, diff, review, and hand off to an AI or another code generation pipeline.

## Product Flow

1. Launch the app.
2. Create a new machine and define its initial state.
3. Use the left palette to add reusable states, events, and types.
4. Build the graph on the canvas by placing states and connecting them with transitions.
5. Use the right inspector to refine the selected state, event, type, or transition.
6. Export the machine as Markdown from the toolbox.

## Architecture

The codebase is split into a small number of focused areas:

- `SwiftMachine/App`: app entry point and dependency injection setup
- `SwiftMachine/Domain`: state machine models, editor document, validation, layout, and Markdown export rendering
- `SwiftMachine/Features`: SwiftUI features and observable stores for the wizard, canvas, palettes, inspectors, transition composition, and export
- `SwiftMachineTests`: Swift Testing coverage for domain rules, store behavior, layout, and export rendering

The app uses a state-driven architecture with small feature stores and a shared composition root for wiring dependencies.

## Project Status

What is working now:

- machine bootstrap through the wizard
- visual editing in a three-pane shell
- reusable type library with structs and enums
- reusable event library with typed payloads
- state payload editing
- transition authoring with event binding
- target-state value mapping from source state, event payload, literals, and custom notes
- guard and effect references on transitions
- Markdown preview and save-to-disk export

What is intentionally modest in the MVP:

- the app is focused on modeling and export, not code generation
- export is currently Markdown only
- the README does not assume any persistence or import workflow beyond what is present in the app today

## Getting Started

### Requirements

- Xcode with macOS app development support
- macOS target matching the project settings in `SwiftMachine.xcodeproj`

### Run the app

1. Open [SwiftMachine.xcodeproj](/Users/thibaultwittemberg/Developer/SideEffect/SwiftMachine/SwiftMachine.xcodeproj).
2. Select the `SwiftMachine` scheme.
3. Run the app on macOS.

### Run the tests

```sh
xcodebuild test -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS'
```

The test suite covers the domain model, validation, editor layout behavior, feature stores, and export rendering.

## Export Format

The export renderer generates a compact Markdown document with stable sections for:

- machine metadata
- reusable types
- states
- events
- transitions

The output deliberately omits editor-only identifiers and layout state so exported specs stay reviewable and deterministic.

## License

SwiftMachine is released under the MIT License. See [LICENSE](/Users/thibaultwittemberg/Developer/SideEffect/SwiftMachine/LICENSE).
