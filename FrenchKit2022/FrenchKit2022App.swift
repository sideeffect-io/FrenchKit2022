//
//  FrenchKit2022App.swift
//  FrenchKit2022
//
//  Created by Thibault Wittemberg on 16/09/2022.
//

import StateMachinePackage
import SwiftUI

func makeViewStateMachine(initialState: SupermarketState) -> ViewStateMachine<SupermarketState, SupermarketEvent> {
  let updateStock = UpdateStock { cart in
    print("side effect: updating the stock ...")
    try await Task.sleep(nanoseconds: 2_000_000_000)
    print("side effect: the stock has been updated!")
  }

  let updateCustomerQueue = UpdateCustomerQueue {
    print("side effect: updating the customer queue ...")
    try await Task.sleep(nanoseconds: 2_000_000_000)
    print("side effect: the customer queue has been updated!")
  }

  let executeTransaction = ExecuteTransaction { price, creditCard in
    print("side effect: executing the transaction ...")
    try await Task.sleep(nanoseconds: 2_000_000_000)
    let result = Bool.random()
    print("side effect: the transaction is done with the result \(result)!")
    return result
  }

  let supermarketStateMachine = makeSupermarketStateMachine(
    initialState: initialState,
    updateStock: updateStock,
    updateCustomerQueue: updateCustomerQueue,
    executeTransaction: executeTransaction
  )

  return ViewStateMachine(stateMachine: supermarketStateMachine)
}

@main
struct FrenchKit2022App: App {
  var body: some Scene {
    WindowGroup {
      ContentView(stateMachine: makeViewStateMachine(initialState: .fillingInTheCart(.empty)))
    }
  }
}
