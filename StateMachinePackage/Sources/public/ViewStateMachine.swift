//
//  ViewStateMachine.swift
//  
//
//  Created by Thibault Wittemberg on 18/09/2022.
//

import SwiftUI

/// Consumes an AsyncStateMachine and publishes the state as a Combine publisher so the View can be refreshed
public class ViewStateMachine<State, Event>: ObservableObject where State: Sendable, Event: Sendable {
  @Published
  public private(set) var state: State

  private let asyncStateMachine: AsyncStateMachine<State, Event>

  public init(stateMachine: StateMachine<State, Event>) {
    self.state = stateMachine.initial
    self.asyncStateMachine = AsyncStateMachine(
      stateMachine: stateMachine
    )
  }

  @MainActor
  func publish(_ state: State) {
    self.state = state
  }

  public func send(_ event: Event) {
    self.asyncStateMachine.send(event)
  }

  public func start() async {
    for try await state in self.asyncStateMachine {
      await self.publish(state)
    }
  }
}

