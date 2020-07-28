import XCTest
@testable import SwiftGraphQLParser

class ParserTests: XCTestCase {
    func testParse() throws {
        let query = """
            fragment CustomerSummary on Customer {
                id
                defaultAddress {
                id
                    countryCode: countryCodeV2
                    formattedArea
                }
                email
                phone
                displayName
                firstName
                lastName
                hasNote
                image {
                id
                    transformedSrc(maxWidth: $imageMaxSize, maxHeight: $imageMaxSize)
                }
                ordersCount
                tags
                totalSpent
            }

            query CustomerList($after: String, $query: String, $imageMaxSize: Int!) {
                customers(first: 50, after: $after, sortKey: NAME, query: $query) {
                    edges {
                        cursor
                        node {
                            ...CustomerSummary
                        }
                    }
                    pageInfo {
                        hasNextPage
                    }
                }
            }
        """
        
        let document = try parse(query)
		let expectedDocument = Document(definitions: [ExecutableDefinition.fragment(FragmentDefinition(fragmentName: "CustomerSummary", typeCondition: TypeCondition(namedType: "Customer"), directives: [], selectionSet: [Selection.field(Field(alias: nil, name: "id", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "defaultAddress", arguments: [], directives: [], selectionSet: Optional([Selection.field(Field(alias: nil, name: "id", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: Optional("countryCode"), name: "countryCodeV2", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "formattedArea", arguments: [], directives: [], selectionSet: nil))]))), Selection.field(Field(alias: nil, name: "email", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "phone", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "displayName", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "firstName", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "lastName", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "hasNote", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "image", arguments: [], directives: [], selectionSet: Optional([Selection.field(Field(alias: nil, name: "id", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "transformedSrc", arguments: [Argument(name: "maxWidth", value: Value.variable(Variable(name: "imageMaxSize"))), Argument(name: "maxHeight", value: Value.variable(Variable(name: "imageMaxSize")))], directives: [], selectionSet: nil))]))), Selection.field(Field(alias: nil, name: "ordersCount", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "tags", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "totalSpent", arguments: [], directives: [], selectionSet: nil))])), ExecutableDefinition.operation(OperationDefinition.operation(Operation(operationType: OperationType.query, name: Optional("CustomerList"), variableDefinitions: Optional([VariableDefinition(variable: Variable(name: "after"), type: Type.namedType("String"), defaultValue: nil, directives: []), VariableDefinition(variable: Variable(name: "query"), type: Type.namedType("String"), defaultValue: nil, directives: []), VariableDefinition(variable: Variable(name: "imageMaxSize"), type: Type.nonNullType(Type.namedType("Int")), defaultValue: nil, directives: [])]), directives: [], selectionSet: [Selection.field(Field(alias: nil, name: "customers", arguments: [Argument(name: "first", value: Value.intValue("50")), Argument(name: "after", value: Value.variable(Variable(name: "after"))), Argument(name: "sortKey", value: Value.enumValue("NAME")), Argument(name: "query", value: Value.variable(Variable(name: "query")))], directives: [], selectionSet: Optional([Selection.field(Field(alias: nil, name: "edges", arguments: [], directives: [], selectionSet: Optional([Selection.field(Field(alias: nil, name: "cursor", arguments: [], directives: [], selectionSet: nil)), Selection.field(Field(alias: nil, name: "node", arguments: [], directives: [], selectionSet: Optional([Selection.fragmentSpread(FragmentSpread(fragmentName: "CustomerSummary", directives: []))])))]))), Selection.field(Field(alias: nil, name: "pageInfo", arguments: [], directives: [], selectionSet: Optional([Selection.field(Field(alias: nil, name: "hasNextPage", arguments: [], directives: [], selectionSet: nil))])))])))])))])
		XCTAssertEqual(document, expectedDocument)
	}
	
	func testUnterminatedSelectionSetInFragment() throws {
		let fragment = """
		fragment Fragment on Customer {
		    id
		    email
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .unterminatedSelectionSet)
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 32)
		}
	}
	
	func testMissingFragmentName() throws {
		let fragment = """
		fragment {
		    id
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingFragmentName)
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "fragment {")
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 9)
		}
	}
	
	func testMissingTypeCondition() throws {
		let fragment = """
		fragment Fragment {
		    id
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingTypeCondition)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "fragment"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "fragment Fragment {")
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 9)
		}
	}
	
	func testMissingSelectionSet() throws {
		let fragment = """
		fragment Fragment on Customer
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingSelectionSet)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "fragment"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 9)
		}
	}
	
	func testEmptySelectionSet() throws {
		let fragment = """
		fragment Fragment on Customer {}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .emptySelectionSet)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "{"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 32)
		}
	}
	
	func testVariableDefinitionList() throws {
		let query = """
		query CustomerList() {}
		"""
		XCTAssertThrowsError(try parse(query)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .emptyVariableDefinitionList)
			XCTAssertEqual(parserError.errorRange, query.range(of: "("))
			XCTAssertEqual(parserError.input, query)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "query CustomerList()")
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 20)
		}
	}
	
	func testEmptyArgumentList() throws {
		let fragment = """
		fragment Fragment on Customer {
		    customers() {}
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .emptyArgumentList)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "("))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "fragment Fragment on Customer {\n    customers()")
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 15)
		}
	}
	
	func testUnterminatedArgumentList() throws {
		let fragment = """
		fragment Fragment on Customer {
		    customers(first: 50
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .unterminatedArgumentList)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "("))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 15)
		}
	}
	
	func testMissingArgumentValue() throws {
		let fragment = """
		fragment Fragment on Customer {
		    customers(first:
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingArgumentValue)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "first"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 20)
		}
	}
	
	func testUnterminatedListValue() throws {
		let fragment = """
		fragment Fragment on Customer {
		    customers(first:[) {
		        id
		    }
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .unterminatedListValue)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "["))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "fragment Fragment on Customer {\n    customers(first:[) {")
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 22)
		}
	}

	func testUnterminatedObjectValue() throws {
		let fragment = """
		fragment Fragment on Customer {
		    customers(first:{) {
		        id
		    }
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .unterminatedObjectValue)
			XCTAssertEqual(parserError.errorRange, fragment[fragment.range(of: "{")!.upperBound ..< fragment.endIndex].range(of: "{"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.range(of: "fragment Fragment on Customer {\n    customers(first:{) {")
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 22)
		}
	}
	
	func testMissingObjectValue() {
		let fragment = """
		fragment Fragment on Customer {
		    customers(first: { one:
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingObjectValue)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "one"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 27)
		}
	}
	
	func testMissingDirectiveName() {
		let fragment = """
		fragment Fragment on Customer {
		    field @
		}
		"""
		XCTAssertThrowsError(try parse(fragment)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingDirectiveName)
			XCTAssertEqual(parserError.errorRange, fragment.range(of: "@"))
			XCTAssertEqual(parserError.input, fragment)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 2)
			XCTAssertEqual(parserError.column, 12)
		}
	}
	
	func testUnterminatedVariableDefinitionList() {
		let query = """
		query Query($first: Int
		"""
		XCTAssertThrowsError(try parse(query)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .unterminatedVariableDefinitionList)
			XCTAssertEqual(parserError.errorRange, query.range(of: "("))
			XCTAssertEqual(parserError.input, query)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 13)
		}
	}
	
	func testMissingVariableType() {
		let query = """
		query Query($first:)
		"""
		XCTAssertThrowsError(try parse(query)) { error in
			guard let parserError = error as? ParserError else { return XCTFail() }
			XCTAssertEqual(parserError.type, .missingVariableType)
			XCTAssertEqual(parserError.errorRange, query.range(of: "$"))
			XCTAssertEqual(parserError.input, query)
			XCTAssertEqual(
				parserError.contextualStart ..< parserError.contextualEnd,
				parserError.input.startIndex ..< parserError.input.endIndex
			)
			XCTAssertEqual(parserError.line, 1)
			XCTAssertEqual(parserError.column, 14)
		}
	}
}
