//
//  Policies.swift
//  SwiftyMocky
//
//  Created by Andrzej Michnia on 22.09.2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation

// MARK: - Stubbing Policy
/// Given Policy for treating sequence of events (products). For wr
///
/// - `default`: Use current policy specified for Mock method type
/// - wrap: Default policy in general. When reaching end of sequence of events, index will rewind to beginning (looping)
/// - drop: With this policy, every call drops event. When events count reaches zero, given is removed from mock.
public enum StubbingPolicy {
    case `default`  // use mock default policy for method type
    case wrap       // default
    case drop

    /// Resolves used policy. If self is default, will use inherited, otherwise self
    ///
    /// - Parameter inherited: Inherited (usually global default) policy
    /// - Returns: Policy used. Always .wrap or .drop
    public func real(_ inherited: StubbingPolicy) -> StubbingPolicy {
        switch (self, inherited) {
        case (.default, .default): return .wrap // Special case, wrap is always default in general
        case (.default, _): return inherited    // Use inherited for real policy if self is default
        default: return self                    // If policy specified, use it instead of inherited
        }
    }

    /// Computes new index for stubs array. For wrap will rewind if out of bounds, for drop will not.
    /// Default is handled as wrap.
    ///
    /// - Parameters:
    ///   - index: Index of current element
    ///   - count: Number of elements
    /// - Returns: New index
    public func updated(_ index: Int, with count: Int) -> Int {
        switch self {
        case .default, .wrap: return (index + 1) % count
        case .drop: return index + 1
        }
    }
}

/// Internal, used for marking that stubs have configurable policy
public protocol WithStubbingPolicy: class {
    var policy: StubbingPolicy { get set }
    func with(_ policy: StubbingPolicy) -> Self
}

public extension WithStubbingPolicy {
    func with(_ policy: StubbingPolicy) -> Self {
        self.policy = policy
        return self
    }
}

// MARK: - Sequencing policy
/// Sequencing policy - in which order Given would be resolved.
///
/// - lastWrittenResolvedFirst: Default policy. Last given overrides previous, if they are both with same generocity level
/// - inWritingOrder: Givens would be recalled in order of generocity, respecting writing order (first line resolved first)
public enum SequencingPolicy {
    case lastWrittenResolvedFirst
    case inWritingOrder

    public func sorted<T>(_ array: [T], by order: (T, T) -> Bool) -> [T] {
        switch self {
        case .lastWrittenResolvedFirst: return array.reversed().sorted(by: order)
        case .inWritingOrder: return array.sorted(by: order)
        }
    }
}

/// Has sequencing policy for stubbing methods
public protocol WithSequencingPolicy {
    /// Used sequencibg policy
    var sequencingPolicy: SequencingPolicy { get set }
}

/// Has sequencing policy for stubbing static methods
public protocol WithStaticSequencingPolicy {
    /// Used sequencibg policy
    static var sequencingPolicy: SequencingPolicy { get set }
}
