//===--------------- GenericUnixToolchain.swift - Swift *nix Toolchain ----===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import TSCBasic

/// Toolchain for Unix-like systems.
public final class GenericUnixToolchain: Toolchain {
  enum Error: Swift.Error {
    case unableToFind(tool: String)
  }
  
  public let env: [String: String]

  private let searchPaths: [AbsolutePath]

  public init(env: [String: String]) {
    self.env = env
    self.searchPaths = getEnvSearchPaths(pathString: env["PATH"], currentWorkingDirectory: localFileSystem.currentWorkingDirectory)
  }

  /// Looks in the `executablePath`, if found nothing, looks in the environment search paths.
  /// - Parameter executable: executable to look for [i.e. `swift`].
  private func lookup(executable: String) throws -> AbsolutePath {
    if let path = lookupExecutablePath(filename: executable, searchPaths: [executableDir]) {
      return path
    } else if let path = lookupExecutablePath(filename: executable, searchPaths: searchPaths) {
      return path
    }

    // If we happen to be on a macOS host, some tools might not be in our
    // PATH, so we'll just use xcrun to find them too.
    #if os(macOS)
    return try DarwinToolchain(env: self.env).lookup(executable: executable)
    #else
    throw Error.unableToFind(tool: executable)
    #endif
  }

  public func makeLinkerOutputFilename(moduleName: String, type: LinkOutputType) -> String {
    switch type {
    case .executable: return moduleName
    case .dynamicLibrary: return "lib\(moduleName).so"
    case .staticLibrary: return "lib\(moduleName).a"
    }
  }

  public func getToolPath(_ tool: Tool) throws -> AbsolutePath {
    switch tool {
    case .swiftCompiler:
      return try lookup(executable: "swift")
    case .staticLinker:
      return try lookup(executable: "ar")
    case .dynamicLinker:
      // FIXME: This needs to look in the tools_directory first.
      return try lookup(executable: "clang")
    case .clang:
      return try lookup(executable: "clang")
    case .swiftAutolinkExtract:
      return try lookup(executable: "swift-autolink-extract")
    case .dsymutil:
      return try lookup(executable: "dsymutil")
    }
  }

  public func defaultSDKPath() throws -> AbsolutePath? {
    return nil
  }

  public var shouldStoreInvocationInDebugInfo: Bool { false }

  public func runtimeLibraryName(
    for sanitizer: Sanitizer,
    targetTriple: Triple,
    isShared: Bool
  ) throws -> String {
    return "libclang_rt.\(sanitizer.libraryName)-\(targetTriple.archName).a"
  }
}
