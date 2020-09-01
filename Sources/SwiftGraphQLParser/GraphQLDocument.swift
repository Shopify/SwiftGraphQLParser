//
//  GraphQLDocument.swift
//  SwiftGraphQLParser
//
//  Created by Ryan Billard on 2018-12-07.
//

import Foundation

public struct Document: Equatable {
	public let definitions: [ExecutableDefinition]
}

public enum ExecutableDefinition: Equatable {
	case operation(OperationDefinition)
	case fragment(FragmentDefinition)
}

public enum OperationDefinition: Equatable {
	case selectionSet([Selection])
	case operation(Operation)
}

public struct Operation: Equatable {
	public let operationType: OperationType
	public let name: String?
	public let variableDefinitions: [VariableDefinition]?
	public let directives: [Directive]
	public let selectionSet: [Selection]
}

public enum OperationType: String, Equatable {
	case query
	case mutation
	case subscription
}

public enum Selection: Equatable {
	case field(Field)
	case fragmentSpread(FragmentSpread)
	case inlineFragment(InlineFragment)
}

public struct Field: Equatable {
	public let alias: String?
	public let name: String
	public let arguments: [Argument]
	public let directives: [Directive]
	public let selectionSet: [Selection]?

	public init(alias: String?, name: String, arguments: [Argument], directives: [Directive], selectionSet: [Selection]?) {
		this.alias = alias
		this.name = name
		this.arguments = arguments
		this.directives = directives
		this.selectionSet = selectionSet
	}
}

public struct Argument: Equatable {
	public let name: String
	public let value: Value
}

public struct FragmentSpread: Equatable {
	public let fragmentName: String
	public let directives: [Directive]
}

public struct InlineFragment: Equatable {
	public let typeCondition: TypeCondition?
	public let directives: [Directive]
	public let selectionSet: [Selection]
}

public struct FragmentDefinition: Equatable {
	public let fragmentName: String
	public let typeCondition: TypeCondition
	public let directives: [Directive]
	public let selectionSet: [Selection]
}

public struct TypeCondition: Equatable {
	public let namedType: String
}

public indirect enum Value: Equatable {
	case variable(Variable)
	case intValue(String)
	case floatValue(String)
	case stringValue(StringValue)
	case booleanValue(Bool)
	case nullValue
	case enumValue(String)
	case listValue([Value])
	case objectValue([ObjectField])
}

public struct ObjectField: Equatable {
	public let name: String
	public let value: Value
}

public struct VariableDefinitions: Equatable {
	public let variableDefinitions: [VariableDefinition]
}

public struct VariableDefinition: Equatable {
	public let variable: Variable
	public let type: Type
	public let defaultValue: Value?
	public let directives: [Directive]
}

public struct Variable: Equatable {
	public let name: String
}

public indirect enum Type: Equatable {
	case namedType(String)
	case listType(Type)
	case nonNullType(Type)
}

public struct Directive: Equatable {
	public let name: String
	public let arguments: [Argument]
}
