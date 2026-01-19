# 🔄 Retry

Retry is a nano-library for retrying asynchronous operations. Supports cancellation, customizable backoff duration and exponential factor, and calculates random jitter to avoid the thundering herd problem.

## Installation

You can use the Swift Package Manager to download and import the library into your project:

```swift
dependencies: [
    .package(url: "https://github.com/thecoolwinter/Retry.git", from: "1.0.0")
]
```

Then under `targets`:

```swift
targets: [
    .target(
    	// ...
        dependencies: [
            .product(name: "Retry", package: "Retry")
        ]
    )
]
```

## API

The following two functions are exposed by this library. See their in-source documentation for more details.

```swift
nonisolated(nonsending)
public func retry<Result, ErrorType: Error>(
    maxAttempts: Int,
    backoffFactor: Int = 2,
    backoffDuration: Duration = .milliseconds(100),
    tolerance: Duration? = nil,
    operation: () async throws(ErrorType) -> Result,
) async throws -> Result
```

```swift
nonisolated(nonsending)
public func retryIndefinite<Result, ErrorType: Error>(
    backoffFactor: Int = 2,
    backoffDuration: Duration = .milliseconds(100),
    tolerance: Duration? = nil,
    operation: () async throws(ErrorType) -> Result,
) async throws -> Result
```

As well as a `BackoffStrategy` struct, that calculates exponential backoff.

```swift
public struct BackoffStrategy {
    public init(factor: Int = 2, initial: Duration = .milliseconds(100))
    public mutating func nextDuration() -> Duration
}
```

