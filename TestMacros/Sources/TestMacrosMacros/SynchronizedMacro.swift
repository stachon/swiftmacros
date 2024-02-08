//
//  File.swift
//  
//
//  Created by Martin Stachon on 06.02.2024.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SynchronizedPropertyMacroError: Error, CustomStringConvertible {
    case missingInitializer

    public var description: String {
        switch self {
        case .missingInitializer:
            return "Stored property must have an initializer"
        }
    }
}

public struct SynchronizedPropertyMacro { }

public extension SynchronizedPropertyMacro: AccessorMacro {

    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: Declaration,
        in context: Context
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              binding.accessorBlock == nil,
              let type = binding.typeAnnotation?.type
        else {
            return []
        }

//        // Ignore the "_lock" variable.
//        if identifier.text == "_lock" {
//            return []
//        }

        guard let defaultValue = binding.initializer?.value else {
            throw SynchronizedPropertyMacroError.missingInitializer
        }

        return [
      """
      get {
        defer { \(literal: identifier.text)_lock.unlock() }
        var result: \(type)!
        \(literal: identifier.text)_lock.lock()
        result = \(literal: identifier.text)_storage
        return result
      }
      """,
      """
      set {
        \(literal: identifier.text)_lock.lock()
        \(literal: identifier.text)_storage = newValue
        \(literal: identifier.text)_lock.unlock()
      }
      """,
        ]
    }
}

public extension SynchronizedPropertyMacro: PeerMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
            return []
        }
        return ["""
        private var \(raw: identified.name.text)_inner: T
        private var \(raw: identified.name.text)_lock = NSLock()
        """]
    }
}
