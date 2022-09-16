# StateMachinePackage

Here is the public API of this package:

- `StateMachine`: a wrapper around an initial state, and transitions. `transitions` is a function with this signature: `(State, Event) async -> Transition`.
- `Transition`: the result of a transition. It is an enum with 2 cases. The goal it to return the state (a new one or the same one) and an optional output to execute.
	- `.sameState(output:)`
	- `.newState(state:output:)`
- `SideEffect`: a wrapper around a side effect function that returns an optional `Event`. `SideEffects` will be returned in the `output:` field of a `Transition`.
- `AsyncStateMachine`: an `AsyncSequence`, wrapping a `StateMachine` structure,  forwarding user inputs into the `StateMachine` and delivering a sequence a states over time
- `ViewStateMachine`: a wrapper around a `AsyncStateMachine` that can be used in a UI context. As it conforms to `ObservableObject`, a SwiftUI view can use it as an `@ObservedObject` variable.

The overall idea to create and use a state machine in a SwiftUI context is:

```swift
// define the states and events:
enum State {
  case idle
  case loading
  case loaded(value: Int)
  case failed(error: Error)
}

enum Event {
  case loadingwasRequested(id: String)
  case loadingHasSucceeded(value: Int)
  case loadingHasFailed(error: Error)
}

// define the side effects
struct Load {
  let loadFunction: () async throws -> Int
	
  func callAsFunction(id: String) -> SideEffect<State, Event> {
    SideEffect {
      do {
        let value = try await loadFunction(id: id)
	return .loadingHasSucceeded(value: value)
      } catch {
	return .loadingHasFailed(error: error)
      }
    }
  }
}


// provide a way to create the state machine and provide the side effects to execute
func makeStateMachine(load: Load) -> StateMachine<State, Event> {

  StateMachine(initial: .idle) { state, event in
    switch (state, event) {
    case (.idle, . loadingwasRequested(let id)):
      return .newState(state: .loading, output: load(id: id))

    case (.loading, . loadingHasSucceeded(let value)):
      return .newState(.loaded(value: value))

    case (.loading, . loadingHasFailed(let error):
      return .newState(.failed(error: error)
     
    default:
    	return .sameState()
  }
}

// build the ViewStateMachine from the state machine
var viewStateMachine: ViewStateMachine<State, Event> {
	let load = Load(apiService: ApiService())
	let stateMachine = makeStateMachine(load: load)
	return ViewStateMachine(stateMachine: stateMachine)
}

// inject the ViewStateMachine in your SwiftUI View
struct MyView: View {
  @ObservedObject
  var stateMachine: ViewStateMachine<State, Event>
	
  var body: some View {
    VStack {
      Text("\(self.stateMachine.state)")
      ...
      Button {
	self.stateMachine.send(.loadingWasRequested(id: "3") // sends an event in the underlying `AsyncStateMachine`
      } label: {
	...
      }
    }
    .task {
      await self.stateMachine.start() // iterates over the underlying `AsyncStateMachine` 
    }
  }
}

```
