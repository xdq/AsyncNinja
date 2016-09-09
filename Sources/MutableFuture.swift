//
//  Copyright (c) 2016 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

typealias MutableFallibleFuture<T> = MutableFuture<Fallible<T>>

public class MutableFuture<T> : Future<T>, ThreadSafeContainer {
  typealias ThreadSafeItem = AbstractMutableFutureState<T>
  var head: ThreadSafeItem?

  override func add(handler: FutureHandler<T>) {
    self.update {
      switch $0 {
      case let completedState as CompletedMutableFutureState<Value>:
        handler.handle(value: completedState.value)
        return .keep
      case let incompleteState as SubscribedMutableFutureState<Value>:
        return .replace(SubscribedMutableFutureState(handler: handler, nextNode: incompleteState, owner: self))
      case .none:
        return .replace(SubscribedMutableFutureState(handler: handler, nextNode: nil, owner: self))
      default:
        fatalError()
      }
    }
  }

  @discardableResult
  final func tryComplete(with value: Value) -> Bool {
    let completedItem = CompletedMutableFutureState(value: value)
    let (oldHead, newHead) = self.update { ($0?.isIncomplete ?? true) ? .replace(completedItem) : .keep }
    guard completedItem === newHead else { return false }

    var nextItem = oldHead
    while let currentItem = nextItem as? SubscribedMutableFutureState<Value> {
      currentItem.handler.handle(value: value)
      nextItem = currentItem.nextNode
    }

    return nil != oldHead
  }
}

class AbstractMutableFutureState<T> {
  var isIncomplete: Bool { fatalError() /* abstract */ }
}

final class SubscribedMutableFutureState<T> : AbstractMutableFutureState<T> {
  typealias Value = T
  typealias Handler = FutureHandler<Value>

  let handler: Handler
  let nextNode: SubscribedMutableFutureState<T>?
  let owner: MutableFuture<T>
  override var isIncomplete: Bool { return true }

  init(handler: Handler, nextNode: SubscribedMutableFutureState<T>?, owner: MutableFuture<T>) {
    self.handler = handler
    self.nextNode = nextNode
    self.owner = owner
  }
}

final class CompletedMutableFutureState<T> : AbstractMutableFutureState<T> {
  let value: T
  override var isIncomplete: Bool { return false }

  init(value: T) {
    self.value = value
  }
}
