//
//  StateMachine.swift
//  FrenchKit2022
//
//  Created by Thibault Wittemberg on 17/09/2022.
//

import StateMachinePackage

func makeSupermarketStateMachine(
  initialState: SupermarketState,
  updateStock: UpdateStock,
  updateCustomerQueue: UpdateCustomerQueue,
  executeTransaction: ExecuteTransaction
) -> StateMachine<SupermarketState, SupermarketEvent> {
  StateMachine(initial: initialState) { state, event in
    switch (state, event) {
      case (.fillingInTheCart(var cart), .itemWasAdded(let item)):
        cart.add(item: item)
        return .newState(.fillingInTheCart(cart), output: updateStock(for: cart))

      case (.fillingInTheCart(let cart), .walkingToCashier):
        return .newState(.atTheCheckout(cart), output: updateCustomerQueue())

      case (.atTheCheckout(let cart), .givingMyCreditCard(let card)):
        let price = cart.items.reduce(0) { $0 + $1.price }
        return .newState(.paying(cart, card, price), output: executeTransaction(for: price, and: card))

      case (.paying(let cart, _, _), .paymentHasSucceeded):
        return .newState(.goingHomeHappy(cart))

      case (.paying(let cart, _, _), .paymentHasFailed):
        return .newState(.goingHomeSad(cart))

      case (_, .reset):
        return .newState(.fillingInTheCart(.empty))

      default:
        return .sameState()
    }
  }
}
