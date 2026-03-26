//
//  StoreTools.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

@MainActor
protocol StartableStore: AnyObject {
    func start()
}

struct WithViewStore<Store, Content: View>: View where Store: StartableStore {
    @State private var store: Store
    @State private var didStart = false

    private let content: (Store) -> Content

    init(
        store: @autoclosure @escaping () -> Store,
        @ViewBuilder content: @escaping (Store) -> Content
    ) {
        _store = State(wrappedValue: store())
        self.content = content
    }

    var body: some View {
        content(store)
            .task {
                guard !didStart else {
                    return
                }

                store.start()
                didStart = true
            }
    }
}
