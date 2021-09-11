//
//  AsyncView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import BSON
import NIO

struct AsyncView<T, V: View>: View {
    @State var result: Result<T, Error>?
    let run: () async throws -> T
    let build: (T) -> V
    
    init(run: @escaping () async throws -> T, @ViewBuilder build: @escaping (T) -> V) {
        self.run = run
        self.build = build
    }
    
    var body: some View {
        ZStack {
            switch result {
            case .some(.success(let value)):
                build(value)
            case .some(.failure(let error)):
                Text("Error: \(error)" as String)
            case .none:
                ProgressView().task {
                    do {
                        self.result = .success(try await run())
                    } catch {
                        self.result = .failure(error)
                    }
                }
            }
        }.id(result.debugDescription)
    }
}
