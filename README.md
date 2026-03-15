# SwiftMachine

SwiftMachine is a macOS SwiftUI application for designing and validating state machines.

## Project Layout

- `SwiftMachine/App`: application entry point.
- `SwiftMachine/Domain`: state machine models, lifecycle helpers, and validation.
- `SwiftMachine/Features/StateMachineEditor`: editor views and runtime/store logic.
- `SwiftMachineTests`: Swift Testing coverage for the domain and runtime behavior.

## Getting Started

1. Open `SwiftMachine.xcodeproj` in Xcode.
2. Select the `SwiftMachine` scheme.
3. Run the app on macOS.

To run the test suite from the command line:

```sh
xcodebuild test -project SwiftMachine.xcodeproj -scheme SwiftMachine -destination 'platform=macOS'
```

## License

This project is released under the MIT License. See `LICENSE` for details.
