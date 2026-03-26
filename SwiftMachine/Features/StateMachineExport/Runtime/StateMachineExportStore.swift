//
//  StateMachineExportStore.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum StateMachineExportSaveResult: Sendable, Equatable {
    case cancelled
    case saved(URL)
    case failed(String)
}

struct SaveStateMachineExportEffectExecutor: Sendable {
    let save: @MainActor @Sendable (RenderedStateMachineExport) -> StateMachineExportSaveResult

    @MainActor
    func callAsFunction(_ renderedExport: RenderedStateMachineExport) -> StateMachineExportSaveResult {
        save(renderedExport)
    }
}

extension SaveStateMachineExportEffectExecutor {
    static func live() -> Self {
        Self { renderedExport in
            let markdownContentType = UTType(filenameExtension: "md") ?? .plainText
            let savePanel = NSSavePanel()
            savePanel.title = "Save State Machine Spec"
            savePanel.message = "Choose where to save the Markdown state machine spec."
            savePanel.allowedContentTypes = [markdownContentType]
            savePanel.canCreateDirectories = true
            savePanel.nameFieldStringValue = renderedExport.suggestedFilename
            savePanel.isExtensionHidden = false

            guard savePanel.runModal() == .OK,
                  let destinationURL = savePanel.url else {
                return .cancelled
            }

            do {
                try renderedExport.markdown.write(
                    to: destinationURL,
                    atomically: true,
                    encoding: .utf8
                )
                return .saved(destinationURL)
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }
}

@Observable
@MainActor
final class StateMachineExportStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var renderedExport: RenderedStateMachineExport?
        var isObservingDefinition = false
        var isPreviewPresented = false
        var isSaving = false
        var previewErrorMessage: String?
        var lastSavedFileURL: URL?
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case exportTapped
        case dismissPreview
        case saveTapped
        case saveCompleted(StateMachineExportSaveResult)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case save(RenderedStateMachineExport)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let saveRenderedExport: SaveStateMachineExportEffectExecutor
    private let renderer: StateMachineExportRenderer

    init(
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        saveRenderedExport: SaveStateMachineExportEffectExecutor,
        renderer: StateMachineExportRenderer = .init()
    ) {
        state = State(
            snapshot: .empty,
            renderedExport: nil
        )
        self.observeDefinition = observeDefinition
        self.saveRenderedExport = saveRenderedExport
        self.renderer = renderer
    }

    func start() {
        send(.startRequested)
    }

    func send(_ event: Event) {
        let transition = StateMachine.reduce(
            state,
            event,
            renderer: renderer
        )
        state = transition.state

        for effect in transition.effects {
            switch effect {
            case .startObservingDefinition:
                observeDefinition.start { [weak self] snapshot in
                    self?.send(.snapshotDidChange(snapshot))
                }

            case .save(let renderedExport):
                let result = saveRenderedExport(renderedExport)
                send(.saveCompleted(result))
            }
        }
    }
}

extension StateMachineExportStore {
    struct StateMachine {
        static func reduce(
            _ state: State,
            _ event: Event,
            renderer: StateMachineExportRenderer
        ) -> Transition<State, Effect> {
            var state = state

            switch event {
            case .startRequested:
                guard !state.isObservingDefinition else {
                    return .init(state: state, effects: [])
                }

                state.isObservingDefinition = true
                return .init(state: state, effects: [.startObservingDefinition])

            case .snapshotDidChange(let snapshot):
                state.snapshot = snapshot
                state.renderedExport = snapshot.definition.map {
                    renderer.render(
                        definition: $0,
                        revision: snapshot.revision
                    )
                }

                if state.renderedExport == nil {
                    state.isPreviewPresented = false
                    state.previewErrorMessage = nil
                    state.isSaving = false
                }

                return .init(state: state, effects: [])

            case .exportTapped:
                guard state.renderedExport != nil else {
                    return .init(state: state, effects: [])
                }

                state.isPreviewPresented = true
                state.previewErrorMessage = nil
                return .init(state: state, effects: [])

            case .dismissPreview:
                guard !state.isSaving else {
                    return .init(state: state, effects: [])
                }

                state.isPreviewPresented = false
                state.previewErrorMessage = nil
                return .init(state: state, effects: [])

            case .saveTapped:
                guard !state.isSaving,
                      let renderedExport = state.renderedExport else {
                    return .init(state: state, effects: [])
                }

                state.isSaving = true
                state.previewErrorMessage = nil
                return .init(state: state, effects: [.save(renderedExport)])

            case .saveCompleted(let result):
                state.isSaving = false

                switch result {
                case .cancelled:
                    break

                case .saved(let destinationURL):
                    state.lastSavedFileURL = destinationURL
                    state.isPreviewPresented = false
                    state.previewErrorMessage = nil

                case .failed(let message):
                    state.previewErrorMessage = message
                }

                return .init(state: state, effects: [])
            }
        }
    }
}

extension StateMachineExportStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }
}
