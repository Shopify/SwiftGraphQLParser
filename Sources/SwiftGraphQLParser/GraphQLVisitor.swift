//
//  GraphQLVisitor.swift
//  SwiftGraphQLParser
//
//  Created by Ryan Billard on 2018-12-07.
//

import Foundation

public class GraphQLTraverser {
	let document: Document
	let visitor: GraphQLBaseVisitor
	
	public init(document: Document, with visitor: GraphQLBaseVisitor) {
		self.document = document
		self.visitor = visitor
	}
	
	public func traverse() throws {
		try visitor.visitDocument(document: document)
		
		try traverseDefinitions(definitions: document.definitions)
		
		try visitor.exitDocument(document: document)
	}
	
	func traverseDefinitions(definitions: [ExecutableDefinition]) throws {
		try visitor.visitExecutableDefinitions(executableDefinitions: definitions)
		
		for definition in definitions {
			try traverseDefinition(definition: definition)
		}
		
		try visitor.exitExecutableDefinitions(executableDefinitions: definitions)
	}
	
	func traverseDefinition(definition: ExecutableDefinition) throws {
		switch definition {
		case .operation(let operation):
			try traverseOperationDefinition(definition: operation)
		case .fragment(let fragment):
			try traverseFragmentDefinition(definition: fragment)
		}
	}
	
	func traverseOperationDefinition(definition: OperationDefinition) throws {
		try visitor.visitOperationDefinition(operationDefinition: definition)
		
		switch definition {
		case .operation(let operation):
			try traverseOperation(operation: operation)
		case .selectionSet(let selectionSet):
			try traverseSelectionSet(selectionSet: selectionSet)
		}
		
		try visitor.exitOperationDefinition(operationDefinition: definition)
	}
	
	func traverseFragmentDefinition(definition: FragmentDefinition) throws {
		try visitor.visitFragmentDefinition(fragmentDefinition: definition)
		
		try traverseTypeCondition(typeCondition: definition.typeCondition)
		try traverseDirectives(directives: definition.directives)
		try traverseSelectionSet(selectionSet: definition.selectionSet, addTypename: true)
		
		try visitor.exitFragmentDefinition(fragmentDefinition: definition)
	}
	
	func traverseOperation(operation: Operation) throws {
		try visitor.visitOperation(operation: operation)
		
		if let variableDefinitions = operation.variableDefinitions {
			try traverseVariableDefinitions(definitions: variableDefinitions)
		}
		try traverseDirectives(directives: operation.directives)
		if operation.operationType == .subscription {
			
		}
		try traverseSelectionSet(selectionSet: operation.selectionSet, addTypename: operation.operationType != OperationType.subscription)
		
		try visitor.exitOperation(operation: operation)
	}
	
	func traverseSelectionSet(selectionSet: [Selection], addTypename: Bool = false) throws {
		try visitor.visitSelectionSet(selectionSet: selectionSet)
		
		var selectionSet = selectionSet
		if addTypename && !selectionSet.isEmpty {
			if !selectionSet.contains(Selection.typename) {
				selectionSet.insert(Selection.typename, at: 0)
			}
		}
		
		for selection in selectionSet {
			switch selection {
			case .field(let field):
				try traverseField(field: field)
			case .fragmentSpread(let fragmentSpread):
				try traverseFragmentSpread(fragmentSpread: fragmentSpread)
			case .inlineFragment(let inlineFragment):
				try traverseInlineFragment(inlineFragment: inlineFragment)
			}
		}
		
		try visitor.exitSelectionSet(selectionSet: selectionSet)
	}
	
	func traverseTypeCondition(typeCondition: TypeCondition) throws {
		try visitor.visitNamedType(namedType: typeCondition.namedType)
		try visitor.exitNamedType(namedType: typeCondition.namedType)
	}
	
	func traverseDirectives(directives: [Directive]) throws {
		for directive in directives {
			try traverseDirective(directive: directive)
		}
	}
	
	func traverseDirective(directive: Directive) throws {
		try visitor.visitDirective(directive: directive)
		
		try traverseArguments(arguments: directive.arguments)
		
		try visitor.exitDirective(directive: directive)
	}
	
	func traverseVariableDefinitions(definitions: [VariableDefinition]) throws {
		for definition in definitions {
			try traverseVariableDefinition(definition: definition)
		}
	}
	
	func traverseVariableDefinition(definition: VariableDefinition) throws {
		try visitor.visitVariableDefinition(variableDefinition: definition)
		
		try traverseVariable(variable: definition.variable)
		try traverseType(type: definition.type)
		if let defaultValue = definition.defaultValue {
			try traverseValue(value: defaultValue)
		}
		try traverseDirectives(directives: definition.directives)
		
		try visitor.exitVariableDefinition(variableDefinition: definition)
	}
	
	func traverseVariable(variable: Variable) throws {
		try visitor.visitVariable(variable: variable)
		try visitor.exitVariable(variable: variable)
	}
	
	func traverseField(field: Field) throws {
		try visitor.visitField(field: field)
		
		try traverseArguments(arguments: field.arguments)
		try traverseDirectives(directives: field.directives)
		if let selectionSet = field.selectionSet {
			try traverseSelectionSet(selectionSet: selectionSet, addTypename: true)
		}
		
		try visitor.exitField(field: field)
	}
	
	func traverseFragmentSpread(fragmentSpread: FragmentSpread) throws {
		try visitor.visitFragmentSpread(fragmentSpread: fragmentSpread)
		
		try traverseDirectives(directives: fragmentSpread.directives)
		
		try visitor.exitFragmentSpread(fragmentSpread: fragmentSpread)
	}
	
	func traverseInlineFragment(inlineFragment: InlineFragment) throws {
		try visitor.visitInlineFragment(inlineFragment: inlineFragment)
		
		if let typeCondition = inlineFragment.typeCondition {
			try traverseTypeCondition(typeCondition: typeCondition)
		}
		try traverseDirectives(directives: inlineFragment.directives)
		try traverseSelectionSet(selectionSet: inlineFragment.selectionSet, addTypename: true)
		
		try visitor.exitInlineFragment(inlineFragment: inlineFragment)
	}
	
	func traverseArguments(arguments: [Argument]) throws {
		for argument in arguments {
			try traverseArgument(argument: argument)
		}
	}
	
	func traverseArgument(argument: Argument) throws {
		try visitor.visitArgument(argument: argument)
		
		try traverseValue(value: argument.value)
		
		try visitor.exitArgument(argument: argument)
	}
	
	func traverseType(type: Type) throws {
		switch type {
		case .listType(let type):
			try traverseListType(wrappedType: type)
		case .nonNullType(let type):
			try traverseNonNullType(wrappedType: type)
		case .namedType(let type):
			try traverseNamedType(namedType: type)
		}
	}
	
	func traverseNamedType(namedType: String) throws {
		try visitor.visitNamedType(namedType: namedType)
		try visitor.exitNamedType(namedType: namedType)
	}
	
	func traverseNonNullType(wrappedType: Type) throws {
		try visitor.visitNonNullType(nonNullType: wrappedType)
		try traverseType(type: wrappedType)
		try visitor.exitNonNullType(nonNullType: wrappedType)
	}
	
	func traverseListType(wrappedType: Type) throws {
		try visitor.visitListType(listType: wrappedType)
		try traverseType(type: wrappedType)
		try visitor.exitListType(listType: wrappedType)
	}
	
	func traverseValue(value: Value) throws {
		switch value {
		case .variable(let variable):
			try traverseVariable(variable: variable)
		case .booleanValue(let val):
			try visitor.visitBooleanValue(booleanValue: val)
			try visitor.exitBooleanValue(booleanValue: val)
		case .enumValue(let val):
			try visitor.visitEnumValue(enumValue: val)
			try visitor.exitEnumValue(enumValue: val)
		case .floatValue(let val):
			try visitor.visitFloatValue(floatValue: val)
			try visitor.exitFloatValue(floatValue: val)
		case .intValue(let val):
			try visitor.visitIntValue(intValue: val)
			try visitor.exitIntValue(intValue: val)
		case .stringValue(let val):
			try visitor.visitStringValue(stringValue: val)
			try visitor.exitStringValue(stringValue: val)
		case .nullValue:
			try visitor.visitNullValue()
			try visitor.exitNullValue()
		case .listValue(let vals):
			try traverseListValue(values: vals)
		case .objectValue(let vals):
			try traverseObjectValue(values: vals)
		}
	}
	
	func traverseListValue(values: [Value]) throws {
		try visitor.visitListValue(listValue: values)
		
		for value in values {
			try traverseValue(value: value)
		}
		
		try visitor.exitListValue(listValue: values)
	}
	
	func traverseObjectValue(values: [ObjectField]) throws {
		try visitor.visitObjectValue(objectValue: values)
		
		for field in values {
			try traverseObjectField(field: field)
		}
		
		try visitor.exitObjectValue(objectValue: values)
	}
	
	func traverseObjectField(field: ObjectField) throws {
		try visitor.visitObjectField(objectField: field)
		
		try traverseValue(value: field.value)
		
		try visitor.exitObjectField(objectField: field)
	}
}

open class GraphQLBaseVisitor {
	struct Error: LocalizedError {
		let errorDescription: String?
		
		init(description: String) {
			self.errorDescription = description
		}
	}
	
	public init() {}
	
	open func visitDocument(document: Document) throws {}
	
	open func exitDocument(document: Document) throws {}
	
	open func visitOperationDefinition(operationDefinition: OperationDefinition) throws {}
	
	open func exitOperationDefinition(operationDefinition: OperationDefinition) throws {}
	
	open func visitOperation(operation: Operation) throws {}
	
	open func exitOperation(operation: Operation) throws {}
	
	open func visitExecutableDefinitions(executableDefinitions: [ExecutableDefinition]) throws {}
	
	open func exitExecutableDefinitions(executableDefinitions: [ExecutableDefinition]) throws {}
	
	open func visitVariableDefinition(variableDefinition: VariableDefinition) throws {}
	
	open func exitVariableDefinition(variableDefinition: VariableDefinition) throws {}
	
	open func visitSelectionSet(selectionSet: [Selection]) throws {}
	
	open func exitSelectionSet(selectionSet: [Selection]) throws {}
	
	open func visitField(field: Field) throws {}
	
	open func exitField(field: Field) throws {}
	
	open func visitFragmentSpread(fragmentSpread: FragmentSpread) throws {}
	
	open func exitFragmentSpread(fragmentSpread: FragmentSpread) throws {}
	
	open func visitArgument(argument: Argument) throws {}
	
	open func visitInlineFragment(inlineFragment: InlineFragment) throws {}
	
	open func visitFragmentDefinition(fragmentDefinition: FragmentDefinition) throws {}
	
	open func exitFragmentDefinition(fragmentDefinition: FragmentDefinition) throws {}
	
	open func exitNamedType(namedType: String) throws {}
	
	open func exitListType(listType: Type) throws {}
	
	open func exitNonNullType(nonNullType: Type) throws {}
	
	open func visitNamedType(namedType: String) throws {}
	
	open func visitValue(value: Value) throws {}
	
	open func visitVariable(variable: Variable) throws {}
	
	open func visitIntValue(intValue: String) throws {}
	
	open func visitFloatValue(floatValue: String) throws {}
	
	open func visitStringValue(stringValue: StringValue) throws {}
	
	open func visitBooleanValue(booleanValue: Bool) throws {}
	
	open func visitNullValue() throws {}
	
	open func visitEnumValue(enumValue: String) throws {}
	
	open func visitListValue(listValue: [Value]) throws {}
	
	open func visitObjectValue(objectValue: [ObjectField]) throws {}
	
	open func visitObjectField(objectField: ObjectField) throws {}
	
	open func visitDirective(directive: Directive) throws {}
	
	open func visitListType(listType: Type) throws {}
	
	open func visitNonNullType(nonNullType: Type) throws {}
	
	open func exitArgument(argument: Argument) throws {}
	
	open func exitInlineFragment(inlineFragment: InlineFragment) throws {}
	
	open func exitValue(value: Value) throws {}
	
	open func exitVariable(variable: Variable) throws {}
	
	open func exitIntValue(intValue: String) throws {}
	
	open func exitFloatValue(floatValue: String) throws {}
	
	open func exitStringValue(stringValue: StringValue) throws {}
	
	open func exitBooleanValue(booleanValue: Bool) throws {}
	
	open func exitNullValue() throws {}
	
	open func exitEnumValue(enumValue: String) throws {}
	
	open func exitListValue(listValue: [Value]) throws {}
	
	open func exitObjectValue(objectValue: [ObjectField]) throws {}
	
	open func exitObjectField(objectField: ObjectField) throws {}
	
	open func exitDirective(directive: Directive) throws {}
}

