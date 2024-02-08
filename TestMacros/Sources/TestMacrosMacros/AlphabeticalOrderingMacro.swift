import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum AlphabeticalOrderingMacroError: Error, CustomStringConvertible {
    case invalidUsage
    case notAlphabeticallyOrdered(String, String)

    public var description: String {
        switch self {
        case .invalidUsage:
            return "@AlphabeticalOrdering can be attached only to enum or array literal declaration with function calls."
        case let .notAlphabeticallyOrdered(offending, before):
            return "Elements are not alphabetically ordered. \(offending) is before \(before)"
        }
    }
}

public struct AlphabeticalOrdering: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext)
    throws -> [SwiftSyntax.DeclSyntax] {

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            try checkEnumOrdering(declaration: enumDecl)
            return []
        } else if let variableDecl = declaration.as(VariableDeclSyntax.self) {
            try checkArrayOrdering(declaration: variableDecl)
            return []
        } else {
            throw AlphabeticalOrderingMacroError.invalidUsage
        }

    }

    static func checkEnumOrdering(declaration: EnumDeclSyntax) throws {
        // enumerate case identifiers
        let enumCaseNames = declaration.memberBlock.members.flatMap { item -> [String] in
            guard let caseSyntax = item.decl.as(EnumCaseDeclSyntax.self) else { return [] }

            // there might be multiple identifiers per one case line
            return caseSyntax.elements.map { $0.name.text }
        }

        try enumCaseNames.checkOrdering()
    }

    static func checkArrayOrdering(declaration: VariableDeclSyntax) throws {
        guard let binding = declaration.bindings.first,
              let initializer = binding.initializer,
              let initializerValue = initializer.value.as(ArrayExprSyntax.self)
        else {
            throw AlphabeticalOrderingMacroError.invalidUsage
        }

        let initializers = try initializerValue.elements.map {
            guard let element = $0.as(ArrayElementSyntax.self) else {
                throw AlphabeticalOrderingMacroError.invalidUsage
            }
            guard let expression = element.expression.as(FunctionCallExprSyntax.self) else {
                throw AlphabeticalOrderingMacroError.invalidUsage
            }
            guard let calledExpression = expression.calledExpression.as(DeclReferenceExprSyntax.self) else {
                throw AlphabeticalOrderingMacroError.invalidUsage
            }
            return calledExpression.baseName.text
        }

        // check for alphabetical order
        try initializers.checkOrdering()
    }
}

fileprivate extension Array where Element == String {
    func checkOrdering() throws {
        for i in 0..<self.count-1 {
            if self[i] > self[i + 1] {
                throw AlphabeticalOrderingMacroError.notAlphabeticallyOrdered(self[i], self[i + 1])
            }
        }
    }
}
