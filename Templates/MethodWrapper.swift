class MethodWrapper {
    private func deprecatedMessage(_ preferred: String = "") -> String {
        return "@available(*, deprecated, message: \"This constructor is deprecated, and will be removed in v3.1\(preferred)\")\n\t\t"
    }
    private var noStubDefinedMessage: String { return "Stub return value not specified for \(method.name). Use given" }

    private static var registered: [String: Int] = [:]
    private static var suffixes: [String: Int] = [:]
    private static var suffixesWithoutReturnType: [String: Int] = [:]

    let method: SourceryRuntime.Method

    private var registrationName: String {
        var rawName = (method.isStatic ? "sm*\(method.selectorName)" : "m*\(method.selectorName)")
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "(", with: "__")
        .replacingOccurrences(of: ")", with: "")

        var parametersNames = method.parameters.map { "\($0.name)" }

        while let range = rawName.range(of: ":"), let name = parametersNames.first {
            parametersNames.removeFirst()
            rawName.replaceSubrange(range, with: "_\(name)")
        }

        let trimSet = CharacterSet(charactersIn: "_")

        return  rawName
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: "m*", with: "m_")
        .replacingOccurrences(of: "___", with: "__").trimmingCharacters(in: trimSet)
    }
    private var uniqueName: String {
        var rawName = (method.isStatic ? "sm_\(method.selectorName)" : "m_\(method.selectorName)")
        var parametersNames = method.parameters.map { "\($0.name)_of_\($0.typeName.name)" }

        while let range = rawName.range(of: ":"), let name = parametersNames.first {
            parametersNames.removeFirst()
            rawName.replaceSubrange(range, with: "_\(name)")
        }

        return rawName.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
    private var uniqueNameWithReturnType: String {
        let returnTypeRaw = "\(method.returnTypeName)"
        var returnTypeStripped: String = {
            guard let range = returnTypeRaw.range(of: "where") else { return returnTypeRaw }
            var stripped = returnTypeRaw
            stripped.removeSubrange((range.lowerBound)...)
            return stripped
        }()
        returnTypeStripped = returnTypeStripped.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        return "\(uniqueName)->\(returnTypeStripped)"
    }
    private var nameSuffix: String {
        guard let count = MethodWrapper.registered[registrationName] else { return "" }
        guard count > 1 else { return "" }
        guard let index = MethodWrapper.suffixes[uniqueNameWithReturnType] else { return "" }
        return "_\(index)"
    }

    var prototype: String {
        return "\(registrationName)\(nameSuffix)".replacingOccurrences(of: "`", with: "")
    }
    var parameters: [ParameterWrapper] {
        return method.parameters.map { ParameterWrapper($0) }
    }
    var functionPrototype: String {
        let throwing: String = {
            if method.throws {
                return "throws "
            } else if method.rethrows {
                return "rethrows "
            } else {
                return ""
            }
        }()

        let staticModifier: String = method.isStatic ? "public static " : "open "
        if method.isInitializer {
            return "public required \(method.name) \(throwing)"
        } else if method.returnTypeName.isVoid {
            let wherePartIfNeeded: String = {
                if method.returnTypeName.name.hasPrefix("Void") {
                    let range = method.returnTypeName.name.range(of: "Void")!
                    return "\(method.returnTypeName.name[range.upperBound...])"
                } else {
                    return !method.returnTypeName.name.isEmpty ? "\(method.returnTypeName.name) " : ""
                }
            }()
            return "\(staticModifier)func \(method.shortName)\(parametersForStubSignature()) \(throwing)\(wherePartIfNeeded)"
        } else {
            return "\(staticModifier)func \(method.shortName)\(parametersForStubSignature()) \(throwing)-> \(method.returnTypeName.name) "
        }
    }
    var invocation: String {
        guard !method.isInitializer else { return "" }
        if method.parameters.isEmpty {
            return "addInvocation(.\(prototype))"
        } else {
            return "addInvocation(.\(prototype)(\(parametersForMethodCall())))"
        }
    }
    var givenValue: String {
        guard !method.isInitializer else { return "" }
        guard method.throws || !method.returnTypeName.isVoid else { return "" }

        let methodType = method.parameters.isEmpty ? ".\(prototype)" : ".\(prototype)(\(parametersForMethodCall()))"
        let returnType: String = returnsSelf ? "__Self__" : "\(TypeWrapper(method.returnTypeName).stripped)"

        if method.returnTypeName.isVoid {
            return """
            \n\t\tdo {
            \t\t    _ = try methodReturnValue(\(methodType)).casted() as Void
            \t\t}\(" ")
            """
        } else {
            let defaultValue = method.returnTypeName.isOptional ? " = nil" : ""
            return """
            \n\t\tvar __value: \(returnType)\(defaultValue)
            \t\tdo {
            \t\t    __value = try methodReturnValue(\(methodType)).casted()
            \t\t}\(" ")
            """
        }
    }
    var throwValue: String {
        guard !method.isInitializer else { return "" }
        guard method.throws || !method.returnTypeName.isVoid else { return "" }
        let safeFailure = method.isStatic ? "" : "\t\t\tonFatalFailure(\"\(noStubDefinedMessage)\")\n"
        // For Void and Returning optionals - we allow not stubbed case to happen, as we are still able to return
        let noStubHandling = method.returnTypeName.isVoid || method.returnTypeName.isOptional ? "\t\t\t// do nothing" : "\(safeFailure)\t\t\tFailure(\"\(noStubDefinedMessage)\")"
        guard method.throws else {
            return """
            catch {
            \(noStubHandling)
            \t\t}
            """
        }

        return """
        catch MockError.notStubed {
        \(noStubHandling)
        \t\t} catch {
        \t\t    throw error
        \t\t}
        """
    }
    var returnValue: String {
        guard !method.isInitializer else { return "" }
        guard !method.returnTypeName.isVoid else { return "" }

        return "\n\t\treturn __value"
    }
    var equalCase: String {
        guard !method.isInitializer else { return "" }

        if method.parameters.isEmpty {
            return "case (.\(prototype), .\(prototype)):"
        } else {
            let lhsParams = method.parameters.map { "let lhs\($0.name.capitalized)" }.joined(separator: ", ")
            let rhsParams = method.parameters.map { "let rhs\($0.name.capitalized)" }.joined(separator: ", ")
            return "case (.\(prototype)(\(lhsParams)), .\(prototype)(\(rhsParams))):"
        }
    }
    var intValueCase: String {
        if method.parameters.isEmpty {
            return "case .\(prototype): return 0"
        } else {
            let params = method.parameters.enumerated().map { offset, _ in
                return "p\(offset)"
            }
            let definitions = params.joined(separator: ", ")
            let paramsSum = params.map({ "\($0).intValue" }).joined(separator: " + ")
            return "case let .\(prototype)(\(definitions)): return \(paramsSum)"
        }
    }

    var returnsSelf: Bool {
        return !method.returnTypeName.isVoid && TypeWrapper(method.returnTypeName).isSelfType
    }
    var replaceSelf: String {
        return Current.selfType
    }

    init(_ method: SourceryRuntime.Method) {
        self.method = method
    }

    public static func clear() -> String {
        MethodWrapper.registered = [:]
        MethodWrapper.suffixes = [:]
        MethodWrapper.suffixesWithoutReturnType = [:]
        return ""
    }

    func register() {
        MethodWrapper.register(registrationName,uniqueName,uniqueNameWithReturnType)
    }

    static func register(_ name: String, _ uniqueName: String, _ uniqueNameWithReturnType: String) {
        if let count = MethodWrapper.registered[name] {
            MethodWrapper.registered[name] = count + 1
            MethodWrapper.suffixes[uniqueNameWithReturnType] = count + 1
        } else {
            MethodWrapper.registered[name] = 1
            MethodWrapper.suffixes[uniqueNameWithReturnType] = 1
        }

        if let count = MethodWrapper.suffixesWithoutReturnType[uniqueName] {
            MethodWrapper.suffixesWithoutReturnType[uniqueName] = count + 1
        } else {
            MethodWrapper.suffixesWithoutReturnType[uniqueName] = 1
        }
    }

    func returnTypeMatters() -> Bool {
        let count = MethodWrapper.suffixesWithoutReturnType[uniqueName] ?? 0
        return count > 1
    }

    func wrappedInMethodType() -> Bool {
        return !method.isInitializer
    }

    func returningParameter(_ multiple: Bool, _ front: Bool) -> String {
        guard returnTypeMatters() else { return "" }
        let returning: String = "returning: \(returnTypeStripped(method, type: true))"
        guard multiple else { return returning }

        return front ? ", \(returning)" : "\(returning), "
    }

    // Stub
    func stubBody() -> String {
        if method.isInitializer || !returnsSelf {
            return invocation + performCall() + givenValue + throwValue + returnValue
        } else {
            return wrappedStubPrefix()
                + "\t\t" + invocation
                + performCall()
                + givenValue
                + throwValue
                + returnValue
                + wrappedStubPostfix()
        }
    }

    func wrappedStubPrefix() -> String {
        guard !method.isInitializer, returnsSelf else {
            return ""
        }

        let throwing: String = {
            if method.throws {
                return "throws "
            } else if method.rethrows {
                return "rethrows "
            } else {
                return ""
            }
        }()

        return "func _wrapped<__Self__>() \(throwing)-> __Self__ {\n"
    }

    func wrappedStubPostfix() -> String {
        guard !method.isInitializer, returnsSelf else {
            return ""
        }

        let throwing: String = (method.throws || method.rethrows) ? "try ": ""

        return "\n\t\t}"
            + "\n\t\treturn \(throwing)_wrapped()"
    }

    // Method Type
    func methodTypeDeclarationWithParameters() -> String {
        guard !method.parameters.isEmpty else { return "\(prototype)" }
        return "\(prototype)(\(parametersForMethodTypeDeclaration()))"
    }

    // Given
    func containsEmptyArgumentLabels() -> Bool {
        return parameters.contains(where: { $0.parameter.argumentLabel == nil })
    }

    func givenConstructorName(prefix: String = "", deprecated: Bool = false, annotated: Bool = true) -> String {
        let annotation = annotated && deprecated ? deprecatedMessage(deprecatedParametersMessage()) : ""
        let returnTypeString = returnsSelf ? replaceSelf : TypeWrapper(method.returnTypeName).stripped

        if method.parameters.isEmpty {
            return "public static func \(method.shortName)(willReturn: \(returnTypeString)...) -> \(prefix)MethodStub"
        } else {
            return "\(annotation)public static func \(method.shortName)(\(parametersForProxySignature(deprecated: deprecated)), willReturn: \(returnTypeString)...) -> \(prefix)MethodStub"
        }
    }

    func givenConstructorNameThrows(prefix: String = "", deprecated: Bool = false, annotated: Bool = true) -> String {
        let annotation = annotated && deprecated ? deprecatedMessage(deprecatedParametersMessage()) : ""
        if method.parameters.isEmpty {
            return "public static func \(method.shortName)(willThrow: Error...) -> \(prefix)MethodStub"
        } else {
            return "\(annotation)public static func \(method.shortName)(\(parametersForProxySignature(deprecated: deprecated)), willThrow: Error...) -> \(prefix)MethodStub"
        }
    }

    func givenConstructor(prefix: String = "") -> String {
        if method.parameters.isEmpty {
            return "return \(prefix)Given(method: .\(prototype), products: willReturn.map({ Product.return($0) }))"
        } else {
            return "return \(prefix)Given(method: .\(prototype)(\(parametersForProxyInit())), products: willReturn.map({ Product.return($0) }))"
        }
    }

    func givenConstructorThrows(prefix: String = "") -> String {
        if method.parameters.isEmpty {
            return "return \(prefix)Given(method: .\(prototype), products: willThrow.map({ Product.throw($0) }))"
        } else {
            return "return \(prefix)Given(method: .\(prototype)(\(parametersForProxyInit())), products: willThrow.map({ Product.throw($0) }))"
        }
    }

    // Given willProduce
    func givenProduceConstructorName(prefix: String = "") -> String {
        let returnTypeString = returnsSelf ? replaceSelf : TypeWrapper(method.returnTypeName).stripped
        let produceClosure = "(Stubber<\(returnTypeString)>) -> Void"

        if method.parameters.isEmpty {
            return "public static func \(method.shortName)(willProduce: \(produceClosure)) -> \(prefix)MethodStub"
        } else {
            return "public static func \(method.shortName)(\(parametersForProxySignature()), willProduce: \(produceClosure)) -> \(prefix)MethodStub"
        }
    }

    func givenProduceConstructorNameThrows(prefix: String = "") -> String {
        let returnTypeString = returnsSelf ? replaceSelf : TypeWrapper(method.returnTypeName).stripped
        let produceClosure = "(StubberThrows<\(returnTypeString)>) -> Void"

        if method.parameters.isEmpty {
            return "public static func \(method.shortName)(willProduce: \(produceClosure)) -> \(prefix)MethodStub"
        } else {
            return "public static func \(method.shortName)(\(parametersForProxySignature()), willProduce: \(produceClosure)) -> \(prefix)MethodStub"
        }
    }

    func givenProduceConstructor(prefix: String = "") -> String {
        let returnTypeString = returnsSelf ? replaceSelf : TypeWrapper(method.returnTypeName).stripped
        return """
        let willReturn: [\(returnTypeString)] = []
        \t\t\tlet given: \(prefix)Given = { \(givenConstructor(prefix: prefix)) }()
        \t\t\tlet stubber = given.stub(for: (\(returnTypeString)).self)
        \t\t\twillProduce(stubber)
        \t\t\treturn given
        """
    }

    func givenProduceConstructorThrows(prefix: String = "") -> String {
        let returnTypeString = returnsSelf ? replaceSelf : TypeWrapper(method.returnTypeName).stripped
        return """
        let willThrow: [Error] = []
        \t\t\tlet given: \(prefix)Given = { \(givenConstructorThrows(prefix: prefix)) }()
        \t\t\tlet stubber = given.stubThrows(for: (\(returnTypeString)).self)
        \t\t\twillProduce(stubber)
        \t\t\treturn given
        """
    }

    // Verify
    func verificationProxyConstructorName(prefix: String = "", deprecated: Bool = false, annotated: Bool = true) -> String {
        let (annotation, methodName, genericConstrains) = methodInfo(deprecated, annotated)

        if method.parameters.isEmpty {
            return "public static func \(methodName)(\(returningParameter(false,true))) -> \(prefix)Verify\(genericConstrains)"
        } else {
            return "\(annotation)public static func \(methodName)(\(parametersForProxySignature(deprecated: deprecated))\(returningParameter(true,true))) -> \(prefix)Verify\(genericConstrains)"
        }
    }

    func verificationProxyConstructor(prefix: String = "") -> String {
        if method.parameters.isEmpty {
            return "return \(prefix)Verify(method: .\(prototype))"
        } else {
            return "return \(prefix)Verify(method: .\(prototype)(\(parametersForProxyInit())))"
        }
    }

    // Perform
    func performProxyConstructorName(prefix: String = "", deprecated: Bool = false, annotated: Bool = true) -> String {
        let (annotation, methodName, genericConstrains) = methodInfo(deprecated, annotated)

        if method.parameters.isEmpty {
            return "public static func \(methodName)(\(returningParameter(true,false))perform: @escaping \(performProxyClosureType())) -> \(prefix)Perform\(genericConstrains)"
        } else {
            return "\(annotation)public static func \(methodName)(\(parametersForProxySignature(deprecated: deprecated)), \(returningParameter(true,false))perform: @escaping \(performProxyClosureType())) -> \(prefix)Perform\(genericConstrains)"
        }
    }

    func performProxyConstructor(prefix: String = "") -> String {
        if method.parameters.isEmpty {
            return "return \(prefix)Perform(method: .\(prototype), performs: perform)"
        } else {
            return "return \(prefix)Perform(method: .\(prototype)(\(parametersForProxyInit())), performs: perform)"
        }
    }

    func performProxyClosureType() -> String {
        if method.parameters.isEmpty {
            return "() -> Void"
        } else {
            let parameters = self.parameters
                .map { "\($0.justPerformType)" }
                .joined(separator: ", ")
            return "(\(parameters)) -> Void"
        }
    }

    func performProxyClosureCall() -> String {
        if method.parameters.isEmpty {
            return "perform?()"
        } else {
            let parameters = method.parameters
                .map { "\($0.inout ? "&" : "")`\($0.name)`" }
                .joined(separator: ", ")
            return "perform?(\(parameters))"
        }
    }

    func performCall() -> String {
        guard !method.isInitializer else { return "" }
        let type = performProxyClosureType()
        var proxy = method.parameters.isEmpty ? "\(prototype)" : "\(prototype)(\(parametersForMethodCall()))"

        let cast = "let perform = methodPerformValue(.\(proxy)) as? \(type)"
        let call = performProxyClosureCall()

        return "\n\t\t\(cast)\n\t\t\(call)"
    }

    // Helpers
    private func parametersForMethodCall() -> String {
        let generics = getGenericsWithoutConstraints()
        return parameters.map { $0.wrappedForCalls(generics) }.joined(separator: ", ")
    }

    private func parametersForMethodTypeDeclaration() -> String {
        let generics = getGenericsWithoutConstraints()
        return parameters.map { param in
            return param.isGeneric(generics) ? param.genericType : param.nestedType
            }.joined(separator: ", ")
    }

    private func parametersForProxySignature(deprecated: Bool = false) -> String {
        return parameters.map { p in
            guard deprecated else { return "\(p.labelAndName()): \(p.nestedType)" }
            guard let argumentLabel = p.parameter.argumentLabel else { return "\(p.parameter.name): \(p.nestedType)" }
            guard argumentLabel != p.name else { return "\(p.parameter.name): \(p.nestedType)" }
            return "\(argumentLabel) \(p.parameter.name): \(p.nestedType)"
            }.joined(separator: ", ")
    }

    private func deprecatedParametersMessage() -> String {
        let newParams = parameters.map { p in return "\(p.parameter.argumentLabel ?? "_")" }
        let oldParams = parameters.map { p -> String in
            guard let argumentLabel = p.parameter.argumentLabel else { return "\(p.parameter.name)" }
            guard argumentLabel != p.name else { return "\(p.parameter.name)" }
            return "\(argumentLabel)"
        }

        var messages: [String] = []
        for i in 0..<newParams.count {
            if newParams[i] != oldParams[i] {
                messages.append(" remove `\(oldParams[i])` label")
            }
        }

        return " Possible fix: " + messages.joined(separator: ",")
    }

    private func parametersForStubSignature() -> String {
        func replacing(first: String, in full: String, with other: String) -> String {
            guard let range = full.range(of: first) else { return full }
            return full.replacingCharacters(in: range, with: other)
        }
        let prefix = method.shortName
        let full = method.name
        let range = full.range(of: prefix)!
        var unrefined = "\(full[range.upperBound...])"
        parameters.map { p -> (String,String) in
            return ("\(p.type)","\(p.justType)")
            }.forEach {
                unrefined = replacing(first: $0, in: unrefined, with: $1)
        }
        return unrefined
    }

    private func parametersForProxyInit() -> String {
        let generics = getGenericsWithoutConstraints()
        return parameters.map { "\($0.wrappedForProxy(generics))" }.joined(separator: ", ")
    }

    private func isGeneric() -> Bool {
        return method.shortName.contains("<") && method.shortName.contains(">")
    }

    /// Returns list of generics used in method signature, without their constraints (like [T,U,V])
    ///
    /// - Returns: Array of strings, where each strings represent generic name
    private func getGenericsWithoutConstraints() -> [String] {
        let name = method.shortName
        guard let start = name.index(of: "<"), let end = name.index(of: ">") else { return [] }

        var genPart = name[start...end]
        genPart.removeFirst()
        genPart.removeLast()

        let parts = genPart.replacingOccurrences(of: " ", with: "").characters.split(separator: ",").map(String.init)
        return parts.map { stripGenPart(part: $0) }
    }

    /// Returns list of generic constraintes from method signature. Does only contain stuff between '<' and '>'
    ///
    /// - Returns: Array of strings, like ["T: Codable", "U: Whatever"]
    private func getGenericsConstraints(_ generics: [String]) -> [String] {
        let name = method.shortName
        guard let start = name.index(of: "<"), let end = name.index(of: ">") else { return [] }

        var genPart = name[start...end]
        genPart.removeFirst()
        genPart.removeLast()

        let parts = genPart.replacingOccurrences(of: " ", with: "").characters.split(separator: ",").map(String.init)
        return parts.filter {
            let components = $0.components(separatedBy: ":")
            return components.count == 2 && generics.contains(components[0])
        }
    }

    private func getGenericsAmongParameters() -> [String] {
        return getGenericsWithoutConstraints().filter {
            for param in self.parameters {
                if param.isGeneric([$0]) { return true }
            }
            return false
        }
    }

    private func wrapGenerics(_ generics: [String]) -> String {
        guard !generics.isEmpty else { return "" }
        return "<\(generics.joined(separator:","))>"
    }

    private func stripGenPart(part: String) -> String {
        return part.characters.split(separator: ":").map(String.init).first!
    }

    private func returnTypeStripped(_ method: SourceryRuntime.Method, type: Bool = false) -> String {
        let returnTypeRaw = "\(method.returnTypeName)"
        var stripped: String = {
            guard let range = returnTypeRaw.range(of: "where") else { return returnTypeRaw }
            var stripped = returnTypeRaw
            stripped.removeSubrange((range.lowerBound)...)
            return stripped
        }()
        stripped = stripped.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        guard type else { return stripped }
        return "(\(stripped)).Type"
    }

    private func methodInfo(_ deprecated: Bool, _ annotated: Bool)
        -> (annotation: String, methodName: String, genericConstrains: String) {
            let generics = getGenericsAmongParameters()
            let annotation = annotated && deprecated ? deprecatedMessage(deprecatedParametersMessage()) : ""
            let methodName = returnTypeMatters() ? method.shortName : "\(method.callName)\(wrapGenerics(generics))"
            let genericConstrains: String = {
                let constraints = getGenericsConstraints(generics)
                guard !constraints.isEmpty else { return "" }

                return " where \(constraints.joined(separator: ", "))"
            }()
            return (annotation, methodName, genericConstrains)
    }
}
