//
//  Copyright (c) 2016-2017 Anton Mironov
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

import XCTest
import Dispatch
@testable import AsyncNinja
#if os(Linux)
  import Glibc
#endif

class Channel_Merge2Tests: XCTestCase {
  
  static let allTests = [
    ("testMergeInts", testMergeInts),
    ("testMergeIntsAndStrings", testMergeIntsAndStrings),
  ]

  func testMergeInts() {
    multiTest {
      let producerOfOdds = Producer<Int, String>()
      let producerOfEvents = Producer<Int, String>()
      let channelOfNumbers = merge(producerOfOdds, producerOfEvents)
      let sema = DispatchSemaphore(value: 0)


      channelOfNumbers.extractAll { (numbers, stringsOfError) in
        XCTAssertEqual(numbers, [1, 3, 2, 4, 5, 6, 7, 8])
        XCTAssertEqual(stringsOfError.success!.0, "Hello")
        XCTAssertEqual(stringsOfError.success!.1, "World")

        sema.signal()
      }

      DispatchQueue.global().async {
        producerOfOdds.send(1)
        producerOfOdds.send(3)
        producerOfEvents.send(2)
        producerOfEvents.send(4)
        producerOfOdds.send(5)
        producerOfEvents.send(6)
        producerOfOdds.send(7)
        producerOfOdds.succeed(with: "Hello")
        producerOfEvents.send(8)
        producerOfEvents.succeed(with: "World")
      }

      sema.wait()
    }
  }

  func testMergeIntsAndStrings() {
    let fixtureNumbers: [Either<Int, String>] = [.left(1), .left(3), .right("two"), .right("four"), .left(5), .right("six"), .left(7), .right("eight")]

    multiTest {
      let producerOfOdds = Producer<Int, String>()
      let producerOfEvents = Producer<String, String>()
      let channelOfNumbers = merge(producerOfOdds, producerOfEvents, bufferSize: .specific(8))
      let sema = DispatchSemaphore(value: 0)

      channelOfNumbers.extractAll { (numbers, stringsOfError) in
        XCTAssertEqual(numbers.count, fixtureNumbers.count)
        for (number, fixture) in zip(numbers, fixtureNumbers) {
          XCTAssert(number == fixture)
        }
        XCTAssertEqual(stringsOfError.success!.0, "Hello")
        XCTAssertEqual(stringsOfError.success!.1, "World")

        sema.signal()
      }

      DispatchQueue.global().async {
        producerOfOdds.send(1)
        producerOfOdds.send(3)
        producerOfEvents.send("two")
        producerOfEvents.send("four")
        producerOfOdds.send(5)
        producerOfEvents.send("six")
        producerOfOdds.send(7)
        producerOfOdds.succeed(with: "Hello")
        producerOfEvents.send("eight")
        producerOfEvents.succeed(with: "World")
      }

      sema.wait()
    }
  }
}
