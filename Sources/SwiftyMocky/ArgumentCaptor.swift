/// - Parameter ValueType: The type of value to be captured
public class ArgumentCaptor<ValueType> {
	/// Defines which values will be captured
	public enum CaptureBehavior {
		/// Always record passed value
		case captureAllValues
		/// Only record passed value when captured parameter passes the filter provided to the
		/// [capture()](x-source-tag://ArgumentCaptor.capture) method
		case captureWhenValueMatchesThis
		/// Only record passed value when captured parameter passes the filter provided to the
		/// [capture()](x-source-tag://ArgumentCaptor.capture) method AND all non-capturing parameters matched
		case captureWhenValueMatchesThisAndAllNonCapturingParams
		/// Only record passed value when captured parameter does not pass the filter provided to the
		/// [capture()](x-source-tag://ArgumentCaptor.capture) method
		case captureWhenValueDoesNotMatchThis
	}

	/// Last captured value (if any)
	public var value: ValueType? {
		return allValues.last
	}
	/// All captured values
	public var allValues = [ValueType]()

	private let behavior: CaptureBehavior

	public convenience init() {
		self.init(.captureWhenValueMatchesThisAndAllNonCapturingParams)
	}

	public init(_ behavior: CaptureBehavior) {
		self.behavior = behavior
	}

	/// Return parameter matcher which captures the argument.
	/// - Parameter matchFunction: Whether or not the observed value should match
	/// - Tag: ArgumentCaptor.capture
	public func capture(_ value: ValueType, using matchFunction: ((ValueType) -> Bool)?, nonCapturingParamsMatch: Bool) -> Bool {
		let matches = matchFunction?(value) ?? true
		self.appendValueAccordingToBehavior(value, matches: matches, nonCapturingParamsMatch: nonCapturingParamsMatch)
		return matches
	}

	private func appendValueAccordingToBehavior(_ value: ValueType, matches: Bool, nonCapturingParamsMatch: Bool) {
		switch behavior {
		case .captureAllValues:
			allValues.append(value)
			break
		case .captureWhenValueMatchesThis:
			if matches {
				allValues.append(value)
			}
			break
		case .captureWhenValueMatchesThisAndAllNonCapturingParams:
			if matches && nonCapturingParamsMatch {
				allValues.append(value)
			}
			break
		case .captureWhenValueDoesNotMatchThis:
			if !matches {
				allValues.append(value)
			}
			break
		}
	}
}
