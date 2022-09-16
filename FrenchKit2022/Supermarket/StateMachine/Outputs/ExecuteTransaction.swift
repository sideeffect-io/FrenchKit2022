//
//  ExecuteTransactiont.swift
//  FrenchKit2022
//
//  Created by Thibault Wittemberg on 17/09/2022.
//

import StateMachinePackage

struct ExecuteTransaction {
  // we capture a dependency to be able to use it in the side effect
  // Be careful, this one can throw and we care about it
  let submitPayment: (Price, CreditCard) async throws -> Bool

  func callAsFunction(for price: Price, and creditCard: CreditCard) -> SideEffect<SupermarketEvent> {
    SideEffect {
      do {
        let result = try await submitPayment(price, creditCard)
        return result ? .paymentHasSucceeded : .paymentHasFailed
      } catch {
        return .paymentHasFailed
      }
    }
  }
}
