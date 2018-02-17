//
//  ProtocolWithSimilarMethods.swift
//  SwiftyMocky
//
//  Created by Andrzej Michnia on 31.01.2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol ProtocolMethodsThatDifferOnlyInReturnType {
    func foo(bar: String) -> String
    func foo(bar: String) -> Int
}

class A {
    let id: Int
    init(_ id: Int) {
        self.id = id
    }
}
class B {
    let id: Int
    init(_ id: Int) {
        self.id = id
    }
}

//sourcery: AutoMockable
protocol ProtocolMethodsGenericThatDifferOnlyInReturnType {
    func foo<T>(bar: T) -> String
    func foo<T>(bar: T) -> Int
    func foo<T>(bar: T) -> Float where T: A
    func foo<T>(bar: T) -> Float where T: B
    func foo<T>(bar: T) -> Double where T: B
}
