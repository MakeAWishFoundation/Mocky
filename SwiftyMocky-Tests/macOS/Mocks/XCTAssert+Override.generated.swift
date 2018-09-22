// Generated using Sourcery 0.14.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
import XCTest

public func XCTAssertThrowsError<T, E: Error>(_ expression: @autoclosure () throws -> T, of error: E.Type, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    let throwMessage = message().isEmpty ? "Expected \(T.self) thrown" : message()
    XCTAssertThrowsError(expression, throwMessage, file: file, line: line) { errorThrown in
        let typeMessage = message().isEmpty ? "Expected \(T.self), got \(String(describing: errorThrown))" : message()
        XCTAssertTrue(errorThrown is E, typeMessage, file: file, line: line)
    }
}

public func XCTAssertThrowsError<T, E>(_ expression: @autoclosure () throws -> T, error: E, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) where E: Error, E: Equatable {
    let throwMessage = message().isEmpty ? "Expected \(error) thrown" : message()
    XCTAssertThrowsError(expression, throwMessage, file: file, line: line) { errorThrown in
        let typeMessage = message().isEmpty ? "Expected \(error), got \(String(describing: errorThrown))" : message()
        XCTAssertTrue((errorThrown as? E) == error, typeMessage, file: file, line: line)
    }
}
