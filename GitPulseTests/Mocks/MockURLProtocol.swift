//  MockURLProtocol.swift
//  GitPulseTests

import Foundation

/// A `URLProtocol` subclass that intercepts all HTTP requests in a `URLSession`
/// configured to use it, allowing tests to provide canned responses without
/// making real network calls.
///
/// Usage:
/// ```swift
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
///
/// MockURLProtocol.requestHandler = { request in
///     let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)!
///     return (response, someData)
/// }
/// ```
final class MockURLProtocol: URLProtocol {

  /// The handler that tests set to provide a canned `(HTTPURLResponse, Data)` for
  /// each intercepted request.
  ///
  /// - Important: This must be set before making any request through a session
  ///   that uses `MockURLProtocol`. A `fatalError` is raised if it is `nil`.
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      fatalError("MockURLProtocol.requestHandler not set")
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
