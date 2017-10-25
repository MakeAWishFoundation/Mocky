//
//  Mock+Assertions.swift
//  Pods
//
//  Created by przemyslaw.wosko on 19/05/2017.
//
//

import Foundation
import XCTest

/// Verify that given method was called on mock object at least once
///
/// - Parameters:
///   - object: Mock instance
///   - method: Method signature with wrapped parameters (Parameter<ValueType>)
///   - file: -
///   - line: -
public func Verify<T: Mock>(_ object: T, _ method: T.VerificationProxy, file: StaticString = #file, line: UInt = #line) {
    let invocations = object.matchingCalls(method)
    XCTAssert(invocations.count > 0, "Expeced: any invocations of `\(method)`, but was: \(invocations.count)", file: file, line: line)
}

/// Verify that given method was called on mock object exact number of times
///
/// - Parameters:
///   - object: Mock instance
///   - count: Number of invocations
///   - method: Method signature with wrapped parameters (Parameter<ValueType>)
///   - file: -
///   - line: -
public func Verify<T: Mock>(_ object: T, _ count: UInt, _ method: T.VerificationProxy, file: StaticString = #file, line: UInt = #line) {
    let invocations = object.matchingCalls(method)
    XCTAssert(invocations.count == Int(count), "Expeced: \(count) invocations of `\(method)`, but was: \(invocations.count)", file: file, line: line)
}

/// Setup return value for method stubs in mock instance. When this method will be called on mock, it
/// will check for first matching given, with following rules:
/// 1. First check most specific givens (with explicit parameters - .value), then for wildcard parameters (.any)
/// 2. More recent givens have higher priority than older ones
/// 3. When two given's have same level of explicity, like:
///     ```
///     Given(mock, .do(with: .value(1), and: .any(Int.self))
///     Given(mock, .do(with: .any(Int.self), and: .value(1))
///     ```
///     Method stub will return most recent one.
///
/// - Parameters:
///   - object: Mock instance
///   - method: Method signature with wrapped parameters (Parameter<ValueType>) and return value
public func Given<T: Mock>(_ object: T, _ method: T.MethodProxy) {
    object.given(method)
}
