import Foundation

// MARK: - Parameter

/// Parameter wraps method attribute, allowing to make a difference between explicit value,
/// expressed by `.value` case and wildcard value, expressed by `.any` case.
///
/// Whole idea is to be able to test and specify behaviours, in both generic and explicit way
/// (and any mix of these two). Every test method matches mock methods in signature, but changes attributes types
/// to Parameter.
///
/// That allows pattern like matching between two Parameter values:
/// - **.any** is equal to every other parameter. (**!!!** actual case name is `._`, but it is advised to use `.any`)
/// - **.value(p1)** is equal to **.value(p2)** only, when p1 == p2
///
/// **Important!** Comparing parameters, where ValueType is not Equatable will result in fatalError,
/// unless you register comparator for its *ValueType* in **Matcher** instance used (typically Matcher.default)
///
/// - any: represents and matches any parameter value
/// - value: represents explicit parameter value
public enum Parameter<ValueType> {
    /// Wildcard - any value
    case `_`
    /// Explicit value
    case value(ValueType)
    /// Any value for which the given closure returns true
    case matching((ValueType) -> Bool)
    /// - $0: The argument captor to be used for capturing
    /// - $1: An optional function that decides whether the value being evaluated matches or not
    case capturing(ArgumentCaptor<ValueType>, where: ((ValueType) -> Bool)? = nil)

    /// Represents and matches any parameter value - syntactic sugar for `._` case.
    public static var any: Parameter<ValueType> { return Parameter<ValueType>._ }

    /// Represents and matches any parameter value - syntactic sugar for `._` case. Used, when needs to explicitely specify
    /// wrapped *ValueType* type, to resolve ambiguity between methods with same signatures, but different attribute types.
    ///
    /// - Parameter type: Explicitly specify ValueType type
    /// - Returns: any parameter
    public static func any<T>(_ type: T.Type) -> Parameter<T> {
        return Parameter<T>._
    }

    public var shortDescription: String {
        switch self {
        case ._: return ".any"
        case .value(let value as GenericAttribute): return value.shortDescription
        case .value(let value): return String(describing: value)
        case .matching: return ".matching(\(String(describing: ValueType.self)) -> Bool)"
        case .capturing: return ".capturing(\(String(describing: ValueType.self)) -> Bool)"
        }
    }
}

// MARK: - Parameter convenience initializers

public extension Parameter where ValueType: AnyObject {

    /// Represents and matches values on an "same instance" basis.
    ///
    /// - Parameter instance: Instance to match against
    static func sameInstance<T: AnyObject>(as instance: T) -> Parameter<ValueType> {
        return .matching { this in
            guard let thisCasted = this as? T else { return false }
            return thisCasted === instance
        }
    }

    /// Represents and matches whether parameter is of specific type, using `is` operator.
    ///
    /// - Parameter type: Type to match against
    static func isInstance<T: AnyObject>(of type: T.Type) -> Parameter<ValueType> {
        return .matching { $0 is T }
    }
}

public extension Parameter {

    /// Allows combining multiple Parameter constraints into one Parameter constraint.
    ///
    /// - Parameter matching: List of parameter constraints
    static func all(_ matching: Parameter<ValueType>...) -> Parameter<ValueType> {
        return .matching { value -> Bool in
            return matching.contains { !Parameter<ValueType>.compare(lhs: $0, rhs: .value(value), with: .default) }
        }
    }
}

// MARK: - Optionality checks

public protocol OptionalType: ExpressibleByNilLiteral {
    var isNotNil: Bool { get }
}

extension Optional: OptionalType {
    public var isNotNil: Bool {
        switch self {
        case .some: return true
        case .none: return false
        }
    }
}

public extension Parameter where ValueType: OptionalType {
    static var notNil: Parameter<ValueType> {
        return Parameter.matching { $0.isNotNil }
    }
}

// MARK: - Order

public extension Parameter where ValueType: GenericAttributeType {
    /// Used for invocations sorting purpose.
    var intValue: Int {
        switch self {
        case ._: return 0
        case let .value(generic): return generic.intValue
        case .matching: return 1
        case .capturing: return 1
        }
    }
}

public extension Parameter {
    /// Used for invocations sorting purpose.
    var intValue: Int {
        switch self {
        case ._: return 0
        case .value: return 1
        case .matching: return 1
        case .capturing: return 1
        }
    }
}

// MARK: - Equality
public extension Parameter {
    /// Returns whether given two parameters are matching each other, with following rules:
    ///
    /// 1. if parameter is .any - it is equal to any other parameter
    /// 2. if both are .value - then compare wrapped ValueType instances.
    /// 3. if they are not Equatable (or not a Sequences of Equatable), use provided matcher instance
    ///
    /// - Parameters:
    ///   - lhs: First parameter
    ///   - rhs: Second parameter
    ///   - matcher: Matcher instance
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true, if first is matching second
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let lhsValue), .value(let rhsValue)):
            guard let compare = matcher.comparator(for: ValueType.self) else {
                let message = "No registered comparators for \(String(describing: ValueType.self))"
                print("[FATAL] \(message)")
                matcher.onFatalFailure(message)
                Failure(message)
            }
            return compare(lhsValue,rhsValue)
        default: return false
        }
    }

    /// [Internal] Wraps as generic Parameter instance. Should not be ever called directly.
    ///
    /// - Returns: Wrapped parameter
    func wrapAsGeneric() -> Parameter<GenericAttribute> {
        switch self {
        case ._:
            let attribute = GenericAttribute(
                value: Mirror(reflecting: ValueType.self),
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m) -> Bool in
                    guard let lv = l as? Mirror else { return false }
                    if let rv = r as? Mirror {
                        return lv.subjectType == rv.subjectType
                    } else if let _ = r as? ValueType {
                        return true // .any comparing .value or .matching
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case let .value(value):
            let attribute = GenericAttribute(
                value: value,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m) -> Bool in
                    guard let lv = l as? ValueType  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.value(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? ((ValueType) -> Bool) {
                        return rv(lv)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case let .matching(match):
            let attribute = GenericAttribute(
                value: match,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m, _) -> Bool in
                    guard let lv = l as? ((ValueType) -> Bool)  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.matching(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case .capturing(let captor, let match):
            let attribute = GenericAttribute(
                value: match,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m, p) -> Bool in
                    if let value = r as? ValueType {
                        guard let nonCapturingParamsMatch = p else { fatalError("nonCapturingParamsMatch was nil") }
                        return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        }
    }
}

public extension Parameter where ValueType: GenericAttributeType {
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.value(let lhsGeneric), .value(let rhsGeneric)): return lhsGeneric.compare(lhsGeneric.value,rhsGeneric.value,matcher,nonCapturingParamsMatch)
        default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence, ValueType: Equatable {
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case let (.value(left), .value(right)): return left == right
        default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence, ValueType.Element: Equatable {
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let lhsSequence), .value(let rhsSequence)):
            let leftArray = lhsSequence.map { $0 }
            let rightArray = rhsSequence.map { $0 }

            guard leftArray.count == rightArray.count else { return false }

            let values = (0..<leftArray.count)
            .map { i -> (ValueType.Element, ValueType.Element) in
                return ((leftArray[i]),(rightArray[i]))
            }

            for (left,right) in values {
                guard left == right else { return false }
            }

            return true
        default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence, ValueType.Element: Equatable, ValueType: Equatable {
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case let (.value(left), .value(right)): return left == right
        default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence {
    /// Element
    typealias Element = ValueType.Element
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let lhsSequence), .value(let rhsSequence)):
            let leftArray = lhsSequence.map { $0 }
            let rightArray = rhsSequence.map { $0 }

            guard leftArray.count == rightArray.count else { return false }

            let values = (0..<leftArray.count)
                .map { i -> (Element, Element) in
                    return ((leftArray[i]),(rightArray[i]))
            }

            guard let comparator = matcher.comparator(for: Element.self) else {
                let message = "No registered matcher comparator for \(Element.self)"
                print("[FATAL] \(message)")
                matcher.onFatalFailure(message)
                Failure(message)
            }

            for (left,right) in values {
                guard comparator(left, right) else {
                    return false
                }
            }

            return true
        default: return false
        }
    }

    /// [Internal] Wraps as generic Parameter instance. Should not be ever called directly.
    ///
    /// - Returns: Wrapped parameter
    func wrapAsGeneric() -> Parameter<GenericAttribute> {
        switch self {
        case ._:
            let attribute = GenericAttribute(
                value: Mirror(reflecting: ValueType.self),
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m) -> Bool in
                    guard let lv = l as? Mirror else { return false }
                    if let rv = r as? Mirror {
                        return lv.subjectType == rv.subjectType
                    } else if let _ = r as? ValueType {
                        return true // .any comparing .value
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case let .value(value):
            let attribute = GenericAttribute(
                value: value,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m) -> Bool in
                    guard let lv = l as? ValueType  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.value(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? ((ValueType) -> Bool) {
                        return rv(lv)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case let .matching(match):
            let attribute = GenericAttribute(
                value: match,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m) -> Bool in
                    guard let lv = l as? ((ValueType) -> Bool)  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.matching(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m, nonCapturingParamsMatch: true)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        case .capturing(let captor, let match):
            let attribute = GenericAttribute(
                value: match,
                intValue: intValue,
                shortDescription: shortDescription,
                compare: { (l, r, m, p) -> Bool in
                    guard let lv = l as? ((ValueType, Bool) -> Bool)  else { return false }
                    if let value = r as? ValueType {
                        guard let nonCapturingParamsMatch = p else { fatalError("nonCapturingParamsMatch was nil") }
                        return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                }
            )
            return Parameter<GenericAttribute>.value(attribute)
        }
    }
}

public extension Parameter where ValueType: Equatable {
    /// [Internal] Compare two parameters
    ///
    /// - Parameters:
    ///   - lhs: one
    ///   - rhs: other
    ///   - matcher: Matcher instance used for comparison
    ///   - nonCapturingParamsMatch: Whether or not all non-capturing parameters match
    /// - Returns: true if they are matching, false otherwise
    static func compare(
        lhs: Parameter<ValueType>,
        rhs: Parameter<ValueType>,
        with matcher: Matcher,
        nonCapturingParamsMatch: Bool? = nil
    ) -> Bool {
        switch (lhs, rhs) {
        case (._, _): return true
        case (_, ._): return true
        case (.matching(let match), .value(let value)): return match(value)
        case (.value(let value), .matching(let match)): return match(value)
        case (.capturing(let captor, let match), .value(let value)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case (.value(let value), .capturing(let captor, let match)):
            guard let nonCapturingParamsMatch = nonCapturingParamsMatch else { fatalError("nonCapturingParamsMatch was nil") }
            return captor.capture(value, using: match, nonCapturingParamsMatch: nonCapturingParamsMatch)
        case let (.value(left), .value(right)): return left == right
        default: return false
        }
    }
}
