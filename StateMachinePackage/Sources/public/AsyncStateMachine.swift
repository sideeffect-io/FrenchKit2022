//
//  AsyncStateMachine.swift
//  
//
//  Created by Thibault Wittemberg on 18/09/2022.
//

/// An AsyncStateMachine is an AsyncSequence of states. Each event sent to the
/// AsyncStateMachine is stacked (thanks to an AsyncStream) , waiting to be used when the sequence is being iterated over.
/// `AsyncSequence` just like `Sequence` has to provide an `Iterator` that will provide all the consecutive values.
/// The `Iterator` must implement a `next()` function that will be called every time the consumer requests a new value.
public final class AsyncStateMachine<State, Event>: AsyncSequence, Sendable where State: Sendable, Event: Sendable {
  public typealias Element = State
  public typealias AsyncIterator = Iterator

  // the `AsyncStream` used to receive the user events
  let eventsInput: AsyncStream<Event>.Continuation
  // the same `AsyncStream` used to output the user events in the `next()` function
  let eventsStream: AsyncStream<Event>
  // the description of the state machine we want to run
  let stateMachine: StateMachine<State, Event>

  public init(stateMachine: StateMachine<State, Event>) {
    (self.eventsInput, self.eventsStream) = AsyncStream<Event>.pipe()
    self.stateMachine = stateMachine
  }

  var initialState: State {
    self.stateMachine.initial
  }

  /// stacks a new user event in the internal queue that will be unstacked when a new state is requested
  /// - Parameter event: the event to send into the state machine
  public func send(_ event: Event) {
    self.eventsInput.yield(event)
  }

  public func makeAsyncIterator() -> AsyncIterator {
    Iterator(
      eventsInput: self.eventsInput,
      eventsStream: self.eventsStream.makeAsyncIterator(),
      stateMachine: self.stateMachine
    )
  }

  public struct Iterator: AsyncIteratorProtocol {
    var currentState: State
    let eventsInput: AsyncStream<Event>.Continuation
    var eventsStream: AsyncStream<Event>.AsyncIterator
    let stateMachine: StateMachine<State, Event>
    let sideEffectExecutor = SideEffectExecutor<Event>()
    var initialStateHasBeenSent = false

    init(
      eventsInput: AsyncStream<Event>.Continuation,
      eventsStream: AsyncStream<Event>.AsyncIterator,
      stateMachine: StateMachine<State, Event>
    ) {
      self.currentState = stateMachine.initial
      self.eventsInput = eventsInput
      self.eventsStream = eventsStream
      self.stateMachine = stateMachine
    }

    public mutating func next() async -> Element? {
      await withTaskCancellationHandler {
        // here we could eventually handle the cancellation for the pending Tasks in the sideEffectExecutor
      } operation: {
        guard !Task.isCancelled else { return nil }

        // first return state is the initial state
        guard self.initialStateHasBeenSent else {
          self.initialStateHasBeenSent = true
          print("state machine: returning new state \(self.currentState) ...")
          return self.currentState
        }

        // as transitions might not produce a new state, we iterate over the input events
        // until we have a new state to deliver to the consumer of the AsyncSequence
      loop: while true {

        // unstack the next event from the AsyncStream
        guard let event = await self.eventsStream.next() else {
          return nil
        }

        print("state machine: processing event \(event) ...")

        // execute the transition for the current state and the event
        // this will give us: what is the next state (if any), and what is the output to execute as a side effect
        let transition = await self.stateMachine.transition(self.currentState, event)

        switch transition {
          case .sameState(.some(let sideEffect)):
            // state is the same, we won't deliver it
            // but there is an output to execute
            await self.sideEffectExecutor.execute(sideEffect: sideEffect, eventInput: self.eventsInput)
            continue loop

          case .sameState(.none):
            // state is the same, we won't deliver it
            // no output
            continue loop

          case .newState(let state, .some(let sideEffect)):
            // this is a new state, we will deliver it
            self.currentState = state
            // there is an output to execute
            await self.sideEffectExecutor.execute(sideEffect: sideEffect, eventInput: self.eventsInput)
            break loop

          case .newState(let state, .none):
            // this is a new state, we will deliver it
            // no output
            self.currentState = state
            break loop
        }
      }

        print("state machine: returning new state \(self.currentState) ...")

        // we deliver the new state to the consumer
        return self.currentState
      }
    }
  }
}
