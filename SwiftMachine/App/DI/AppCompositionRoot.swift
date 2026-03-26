//
//  AppCompositionRoot.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct AppCompositionRoot: Sendable {
    let editorCanvasStoreFactory: EditorCanvasStoreFactory
    let swiftMachineWizardStoreFactory: SwiftMachineWizardStoreFactory
    let statePaletteStoreFactory: StatePaletteStoreFactory
    let eventPaletteStoreFactory: EventPaletteStoreFactory
    let typePaletteStoreFactory: TypePaletteStoreFactory
    let stateInspectorStoreFactory: StateInspectorStoreFactory
    let eventInspectorStoreFactory: EventInspectorStoreFactory
    let typeInspectorStoreFactory: TypeInspectorStoreFactory
    let transitionComposerStoreFactory: TransitionComposerStoreFactory
    let transitionInspectorStoreFactory: TransitionInspectorStoreFactory

    init(
        service: CurrentStateMachineDefinitionService = .init()
    ) {
        editorCanvasStoreFactory = .live(service: service)
        swiftMachineWizardStoreFactory = .live(service: service)
        statePaletteStoreFactory = .live(service: service)
        eventPaletteStoreFactory = .live(service: service)
        typePaletteStoreFactory = .live(service: service)
        stateInspectorStoreFactory = .live(service: service)
        eventInspectorStoreFactory = .live(service: service)
        typeInspectorStoreFactory = .live(service: service)
        transitionComposerStoreFactory = .live(service: service)
        transitionInspectorStoreFactory = .live(service: service)
    }
}

extension View {
    func appCompositionRoot(_ compositionRoot: AppCompositionRoot) -> some View {
        self
            .environment(\.editorCanvasStoreFactory, compositionRoot.editorCanvasStoreFactory)
            .environment(\.swiftMachineWizardStoreFactory, compositionRoot.swiftMachineWizardStoreFactory)
            .environment(\.statePaletteStoreFactory, compositionRoot.statePaletteStoreFactory)
            .environment(\.eventPaletteStoreFactory, compositionRoot.eventPaletteStoreFactory)
            .environment(\.typePaletteStoreFactory, compositionRoot.typePaletteStoreFactory)
            .environment(\.stateInspectorStoreFactory, compositionRoot.stateInspectorStoreFactory)
            .environment(\.eventInspectorStoreFactory, compositionRoot.eventInspectorStoreFactory)
            .environment(\.typeInspectorStoreFactory, compositionRoot.typeInspectorStoreFactory)
            .environment(\.transitionComposerStoreFactory, compositionRoot.transitionComposerStoreFactory)
            .environment(\.transitionInspectorStoreFactory, compositionRoot.transitionInspectorStoreFactory)
    }
}
