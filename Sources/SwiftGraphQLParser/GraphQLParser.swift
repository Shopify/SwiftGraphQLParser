import Foundation

public enum ParserErrorType: String {
	case missingFragmentName
	case missingTypeCondition
	case missingSelectionSet
	case unterminatedSelectionSet
	case emptySelectionSet
	case emptyArgumentList
	case unterminatedArgumentList
	case missingArgumentValue
	case unterminatedListValue
	case unterminatedObjectValue
	case missingObjectValue
	case missingDirectiveName
	case emptyVariableDefinitionList
	case unterminatedVariableDefinitionList
	case missingVariableType
}

public struct UnexpectedTokenError: LocalizedError {
	public let token: TokenType
	public let line: Int
	public let column: Int
	
	public var errorDescription: String? {
		return "Unexpected token: \(token) at line: \(line) column: \(column)"
	}
}

public struct ParserError: LocalizedError {
	public let type: ParserErrorType
	public let errorRange: Range<String.Index>
	public let input: String
	public var line: Int
	public let column: Int
	
	let contextualStart: String.Index
	let contextualEnd: String.Index
	
	public init(
		type: ParserErrorType,
		errorRange: Range<String.Index>,
		input: String,
		contextualStart: String.Index,
		contextualEnd: String.Index
	) {
		(self.line, self.column) = errorRange.upperBound.lineAndColumn(in: input)
		self.type = type
		self.errorRange = errorRange
		self.input = input
		self.contextualStart = contextualStart
		self.contextualEnd = contextualEnd
	}
	
	public var errorDescription: String? {
		var prefix: String {
			switch type {
			case .unterminatedSelectionSet:
				return "Unterminated selection set starting"
			case .missingFragmentName:
				return "Missing fragment name"
			case .missingTypeCondition:
				return "Missing type condition"
			case .missingSelectionSet:
				return "Missing selection set"
			case .emptySelectionSet:
				return "Empty selection set starting"
			case .emptyArgumentList:
				return "Empty argument list starting"
			case .unterminatedArgumentList:
				return "Unterminated argument list starting"
			case .missingArgumentValue:
				return "Missing argument value"
			case .unterminatedListValue:
				return "Unterminated list value starting"
			case .unterminatedObjectValue:
				return "Unterminated object value starting"
			case .missingObjectValue:
				return "Missing object value"
			case .missingDirectiveName:
				return "Missing directive name"
			case .emptyVariableDefinitionList:
				return "Empty variable definition list starting"
			case .unterminatedVariableDefinitionList:
				return "Unterminated variable definition list starting"
			case .missingVariableType:
				return "Missing variable type"
			}
		}
		let errorLineRange = input.lineRange(for: errorRange)
		let lineRange = input.lineRange(for: contextualStart ..< errorLineRange.lowerBound)
		let goodRange = input[lineRange.lowerBound ..< errorLineRange.lowerBound].split(separator: "\n", omittingEmptySubsequences: false).dropLast().map { line in " ✓\t" + line }.joined(separator: "\n")
		let badRange = input[errorLineRange.lowerBound ..< max(contextualEnd, errorLineRange.upperBound)].split(separator: "\n", omittingEmptySubsequences: false).map { line in "💥\t" + line }.joined(separator: "\n")
		return "\(prefix) at line: \(line) column: \(column) associated with the following input:\n"
			+ goodRange + (goodRange.isEmpty ? "" : "\n")
			+ badRange
	}
}

private struct InternalParserError: Error {
	let type: ParserErrorType
	let errorRange: Range<String.Index>
	let contextualStart: String.Index
	let contextualEnd: String.Index
	
	init(
		type: ParserErrorType,
		start: ArraySlice<Token>,
		contextualStart: String.Index,
		slice: ArraySlice<Token>
	) {
		precondition(!start.isEmpty)
		
		self.type = type
		self.errorRange = start.first!.range
		self.contextualStart = contextualStart
		self.contextualEnd = slice.first?.range.upperBound ?? start.last!.range.upperBound
	}
}

public func parse(_ input: String) throws -> Document {
	var tokens = ArraySlice(tokenize(input))
	var definitions: [ExecutableDefinition] = []
	
	do {
		while let definition = try tokens.readDefinition() {
			definitions.append(definition)
		}
	} catch let error as InternalParserError {
		throw ParserError(type: error.type, errorRange: error.errorRange, input: input, contextualStart: error.contextualStart, contextualEnd: error.contextualEnd)
	}
	
	if let token = tokens.first {
		let (line, column) = token.range.upperBound.lineAndColumn(in: input)
		throw UnexpectedTokenError(token: token.type, line: line, column: column)
	}
	
	return Document(definitions: definitions)
}

private extension ArraySlice where Element == Token {
	
	mutating func readDefinition() throws -> ExecutableDefinition? {
		guard let first = self.first else { return nil }
		
		if let operationDefinition = try self.readOperationDefinition(startIndex: first.range.lowerBound) {
			return .operation(operationDefinition)
		} else if let fragmentDefinition = try self.readFragmentDefinition(startIndex: first.range.lowerBound) {
			return .fragment(fragmentDefinition)
		} else {
			return nil
		}
	}
	
	mutating func readOperationDefinition(startIndex: String.Index) throws -> OperationDefinition? {
		if let selectionSet = try readSelectionSet(startIndex: startIndex) {
			return .selectionSet(selectionSet)
		} else if let operation = try readOperation(startIndex: startIndex) {
			return .operation(operation)
		}
		return nil
	}
	
	mutating func readFragmentDefinition(startIndex: String.Index) throws -> FragmentDefinition? {
		let start = self
		
		guard case .identifier(let val)? = self.popFirst()?.type,
			val == "fragment" else {
				self = start
				return nil
		}
		
		guard let name = readFragmentName() else {
			throw InternalParserError(type: .missingFragmentName, start: start, contextualStart: startIndex, slice: self)
		}
		
		guard let typeCondition = readTypeCondition() else {
			throw InternalParserError(type: .missingTypeCondition, start: start, contextualStart: startIndex, slice: self)
		}
		
		let directives = try readDirectives(startIndex: startIndex)
		
		guard let selectionSet = try readSelectionSet(startIndex: startIndex) else {
			throw InternalParserError(type: .missingSelectionSet, start: start, contextualStart: startIndex, slice: self)
		}
		return FragmentDefinition(fragmentName: name, typeCondition: typeCondition, directives: directives, selectionSet: selectionSet)
	}
	
	mutating func readFragmentName() -> String? {
		let start = self
		
		guard let name = readName(), name != "on" else {
			self = start
			return nil
		}
		
		return name
	}
	
	mutating func readTypeCondition() -> TypeCondition? {
		let start = self
		
		guard case .identifier(let val)? = self.popFirst()?.type,
			val == "on",
			let type = readNamedType() else {
				self = start
				return nil
		}
		
		return TypeCondition(namedType: type)
	}
	
	mutating func readSelectionSet(startIndex: String.Index) throws -> [Selection]? {
		let start = self
		
		guard self.popFirst()?.type == .leftCurlyBrace else {
			self = start
			return nil
		}
		
		var selections: [Selection] = []
		while let selection = try readSelection(startIndex: startIndex) {
			selections.append(selection)
		}
		
		guard selections.isEmpty == false else {
			throw InternalParserError(type: .emptySelectionSet, start: start, contextualStart: startIndex, slice: self)
		}
		
		guard self.popFirst()?.type == .rightCurlyBrace else {
			throw InternalParserError(type: .unterminatedSelectionSet, start: start, contextualStart: startIndex, slice: self)
		}
		
		return selections
	}
	
	mutating func readSelection(startIndex: String.Index) throws -> Selection? {
		let start = self
		
		if let field = try readField(startIndex: startIndex) {
			return Selection.field(field)
		} else if let fragmentSpread = try readFragmentSpread(startIndex: startIndex) {
			return Selection.fragmentSpread(fragmentSpread)
		} else if let inlineFragment = try readInlineFragment(startIndex: startIndex) {
			return Selection.inlineFragment(inlineFragment)
		}
		
		self = start
		return nil
	}
	
	mutating func readField(startIndex: String.Index) throws -> Field? {
		let start = self
		
		let alias = self.readAlias()
		
		guard let name = self.readName() else {
			self = start
			return nil
		}
		
		let arguments = try self.readArguments(startIndex: startIndex)
		
		let directives = try self.readDirectives(startIndex: startIndex)
		
		let selectionSet = try self.readSelectionSet(startIndex: startIndex)
		
		return Field(alias: alias, name: name, arguments: arguments, directives: directives, selectionSet: selectionSet)
	}
	
	mutating func readAlias() -> String? {
		let start = self
		
		if case TokenType.identifier(let identifier)? = self.popFirst()?.type, self.popFirst()?.type == TokenType.colon {
			return identifier
		}
		
		self = start
		return nil
	}
	
	mutating func readName() -> String? {
		let start = self
		
		if case TokenType.identifier(let identifier)? = self.popFirst()?.type {
			return identifier
		}
		
		self = start
		return nil
	}
	
	mutating func readArguments(startIndex: String.Index) throws -> [Argument] {
		let start = self
		
		guard self.popFirst()?.type == TokenType.leftParentheses else {
			self = start
			return []
		}
		
		var arguments: [Argument] = []
		while let argument = try self.readArgument(startIndex: startIndex) {
			arguments.append(argument)
		}
		
		guard arguments.isEmpty == false else {
			throw InternalParserError(type: .emptyArgumentList, start: start, contextualStart: startIndex, slice: self)
		}
		
		guard self.popFirst()?.type == TokenType.rightParentheses else {
			throw InternalParserError(type: .unterminatedArgumentList, start: start, contextualStart: startIndex, slice: self)
		}
		
		return arguments
	}
	
	mutating func readArgument(startIndex: String.Index) throws -> Argument? {
		let start = self
		
		guard let name = self.readName(),
			self.popFirst()?.type == TokenType.colon else {
				self = start
				return nil
		}
		
		guard let value = try self.readValue(startIndex: startIndex) else {
			throw InternalParserError(type: .missingArgumentValue, start: start, contextualStart: startIndex, slice: self)
		}
		
		return Argument(name: name, value: value)
	}
	
	mutating func readValue(startIndex: String.Index) throws -> Value? {
		if let variable = readVariable() {
			return Value.variable(variable)
		}
		if let simpleValue = readSimpleValue() {
			return simpleValue
		}
		if let listValue = try readListValue(startIndex: startIndex) {
			return Value.listValue(listValue)
		}
		if let objectValue = try readObjectValue(startIndex: startIndex) {
			return Value.objectValue(objectValue)
		}
		return nil
	}
	
	mutating func readVariable() -> Variable? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.dollarSign, case .identifier(let identifier)? = self.popFirst()?.type else {
			self = start
			return nil
		}
		
		return Variable(name: identifier)
	}
	
	mutating func readSimpleValue() -> Value? {
		let start = self
		
		switch self.popFirst()?.type {
		case TokenType.intValue(let val)?:
			return Value.intValue(val)
		case TokenType.floatValue(let val)?:
			return Value.floatValue(val)
		case TokenType.stringValue(let val)?:
			return Value.stringValue(val)
		case TokenType.identifier(let val)? where val == "true":
			return Value.booleanValue(true)
		case TokenType.identifier(let val)? where val == "false":
			return Value.booleanValue(false)
		case TokenType.identifier(let val)? where val == "null":
			return Value.nullValue
		case TokenType.identifier(let val)?:
			return Value.enumValue(val)
		default:
			break
		}
		self = start
		return nil
	}
	
	mutating func readListValue(startIndex: String.Index) throws -> [Value]? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.leftSquareBracket else {
			self = start
			return nil
		}
		
		var values: [Value] = []
		while let value = try readValue(startIndex: startIndex) {
			values.append(value)
		}
		
		guard self.popFirst()?.type == TokenType.rightSquareBracket else {
			throw InternalParserError(type: .unterminatedListValue, start: start, contextualStart: startIndex, slice: self)
		}
		
		return values
	}
	
	mutating func readObjectValue(startIndex: String.Index) throws -> [ObjectField]? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.leftCurlyBrace else {
			self = start
			return nil
		}
		
		var objectFields: [ObjectField] = []
		while let objectField = try self.readObjectField(startIndex: startIndex) {
			objectFields.append(objectField)
		}
		
		guard self.popFirst()?.type == TokenType.rightCurlyBrace else {
			throw InternalParserError(type: .unterminatedObjectValue, start: start, contextualStart: startIndex, slice: self)
		}
		
		return objectFields
	}
	
	mutating func readObjectField(startIndex: String.Index) throws -> ObjectField? {
		let start = self
		
		guard let name = self.readName(),
			self.popFirst()?.type == TokenType.colon else {
				self = start
				return nil
		}
		
		guard let value = try self.readValue(startIndex: startIndex) else {
			throw InternalParserError(type: .missingObjectValue, start: start, contextualStart: startIndex, slice: self)
		}
		
		return ObjectField(name: name, value: value)
	}
	
	mutating func readDirectives(startIndex: String.Index) throws -> [Directive] {
		var directives: [Directive] = []
		
		while let directive = try self.readDirective(startIndex: startIndex) {
			directives.append(directive)
		}
		
		return directives
	}
	
	mutating func readDirective(startIndex: String.Index) throws -> Directive? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.atSign else {
				self = start
				return nil
		}
		
		guard let name = self.readName() else {
			throw InternalParserError(type: .missingDirectiveName, start: start, contextualStart: startIndex, slice: self)
		}
		
		let arguments = try self.readArguments(startIndex: startIndex)
		
		return Directive(name: name, arguments: arguments)
	}
	
	mutating func readFragmentSpread(startIndex: String.Index) throws -> FragmentSpread? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.ellipses,
			let fragmentName = readFragmentName() else {
				self = start
				return nil
		}
		let directives = try readDirectives(startIndex: startIndex)
		return FragmentSpread(fragmentName: fragmentName, directives: directives)
	}
	
	mutating func readInlineFragment(startIndex: String.Index) throws -> InlineFragment? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.ellipses else {
			self = start
			return nil
		}
		
		let typeCondition = readTypeCondition()
		let directives = try readDirectives(startIndex: startIndex)
		
		guard let selectionSet = try readSelectionSet(startIndex: startIndex) else {
			self = start
			return nil
		}
		return InlineFragment(typeCondition: typeCondition, directives: directives, selectionSet: selectionSet)
	}
	
	mutating func readOperation(startIndex: String.Index) throws -> Operation? {
		let start = self
		
		guard let operationType = readOperationType() else {
			self = start
			return nil
		}
		
		let name = readName()
		
		let variableDefinitions = try readVariableDefinitions(startIndex: startIndex)
		
		let directives = try readDirectives(startIndex: startIndex)
		
		guard let selectionSet = try readSelectionSet(startIndex: startIndex) else {
			throw InternalParserError(type: .missingSelectionSet, start: start, contextualStart: startIndex, slice: self)
		}
		
		return Operation(operationType: operationType, name: name, variableDefinitions: variableDefinitions, directives: directives, selectionSet: selectionSet)
	}
	
	mutating func readOperationType() -> OperationType? {
		let start = self
		switch self.popFirst()?.type {
		case TokenType.identifier(let val)? where val == "query":
			return OperationType.query
		case TokenType.identifier(let val)? where val == "mutation":
			return OperationType.mutation
		case TokenType.identifier(let val)? where val == "subscription":
			return OperationType.subscription
		default:
			self = start
			return nil
		}
	}
	
	mutating func readVariableDefinitions(startIndex: String.Index) throws -> [VariableDefinition]? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.leftParentheses else {
			self = start
			return nil
		}
		
		var variableDefinitions: [VariableDefinition] = []
		while let variableDefinition = try readVariableDefinition(startIndex: startIndex) {
			variableDefinitions.append(variableDefinition)
		}
		
		guard variableDefinitions.isEmpty == false else {
			throw InternalParserError(type: .emptyVariableDefinitionList, start: start, contextualStart: startIndex, slice: self)
		}
		
		guard self.popFirst()?.type == TokenType.rightParentheses else {
			throw InternalParserError(type: .unterminatedVariableDefinitionList, start: start, contextualStart: startIndex, slice: self)
		}
		
		return variableDefinitions
	}
	
	mutating func readVariableDefinition(startIndex: String.Index) throws -> VariableDefinition? {
		let start = self
		
		guard let variable = readVariable(),
			self.popFirst()?.type == TokenType.colon else {
				self = start
				return nil
		}
		
		guard let type = readType() else {
			throw InternalParserError(type: .missingVariableType, start: start, contextualStart: startIndex, slice: self)
		}

		let defaultValue = try readDefaultValue(startIndex: startIndex)
		
		let directives = try readDirectives(startIndex: startIndex)
		
		return VariableDefinition(variable: variable, type: type, defaultValue: defaultValue, directives: directives)
	}
	
	mutating func readType() -> Type? {
		if let nonNullType = readNonNullType() {
			return nonNullType
		}
		if let listType = readListType() {
			return listType
		}
		if let namedType = readNamedType() {
			return Type.namedType(namedType)
		}
		return nil
	}
	
	mutating func readNamedType() -> String? {
		let start = self
		
		if case .identifier(let val)? = self.popFirst()?.type {
			return val
		}
		
		self = start
		return nil
	}
	
	mutating func readListType() -> Type? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.leftSquareBracket,
			let type = readType(),
			self.popFirst()?.type == TokenType.rightSquareBracket else {
				self = start
				return nil
		}
		return Type.listType(type)
	}
	
	mutating func readNonNullType() -> Type? {
		let start = self
		
		var type: Type
		if let namedType = readNamedType() {
			type = Type.namedType(namedType)
		} else if let listType = readListType() {
			type = listType
		} else {
			self = start
			return nil
		}
		
		guard self.popFirst()?.type == TokenType.exclamation else {
			self = start
			return nil
		}
		
		return Type.nonNullType(type)
	}
	
	mutating func readDefaultValue(startIndex: String.Index) throws -> Value? {
		let start = self
		
		guard self.popFirst()?.type == TokenType.equalsSign,
			let value = try readValue(startIndex: startIndex) else {
				self = start
				return nil
		}
		
		return value
	}
}
