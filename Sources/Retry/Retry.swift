//
//  BackoffStrategy.swift
//  Retry
//
//  Copyright (C) 2026  Khan Winter
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  imitations under the License.
//

let attosecondsPerSecond: Int64 = 1_000_000_000_000_000_000

/// Retries an async operation with exponential backoff on failure.
///
/// This function attempts to execute the provided operation up to `maxAttempts` times,
/// using an exponential backoff strategy with jitter between attempts. By default, the backoff
/// starts at 100ms and doubles with each retry.
///
/// The retry loop will stop immediately if a `CancellationError` is thrown, propagating
/// the cancellation to the caller.
///
/// ## Example
///
/// ```swift
/// // Retry with default exponential backoff (100ms, 200ms, 400ms)
/// let data = try await retry(maxAttempts: 3) {
///     try await fetchDataFromNetwork()
/// }
///
/// // Retry with custom backoff parameters (500ms, 1500ms, 4500ms)
/// let result = try await retry(
///     maxAttempts: 3,
///     backoffFactor: 3,
///     backoffDuration: .milliseconds(500)
/// ) {
///     try await performDatabaseOperation()
/// }
/// ```
///
/// - Parameters:
///   - maxAttempts: The maximum number of times to attempt the operation. Must be greater than 0.
///   - backoffFactor: The multiplier applied to the backoff duration after each failed attempt.
///     Defaults to `2` for exponential backoff (100ms, 200ms, 400ms, etc.).
///   - backoffDuration: The initial backoff duration before the first retry.
///     Defaults to 100 milliseconds.
///   - tolerance: The allowable timing flexibility for the sleep operation between retries.
///     If `nil`, the system determines an appropriate tolerance. See ``Task/sleep(until:tolerance:clock:)``
///     for more details.
///   - operation: An async throwing closure that performs the operation to be retried.
/// - Returns: The successful result from the operation.
/// - Throws: The error from the final attempt if all retries are exhausted, or `CancellationError`
///   if the task is cancelled during retry.
nonisolated(nonsending)
public func retry<Result, ErrorType: Error>(
    maxAttempts: Int,
    backoffFactor: Int = 2,
    backoffDuration: Duration = .milliseconds(100),
    tolerance: Duration? = nil,
    operation: () async throws(ErrorType) -> Result,
) async throws -> Result {
    var backoffStrategy = BackoffStrategy(factor: backoffFactor, initial: backoffDuration)
    precondition(maxAttempts > 0, "Must have at least one attempt")
    for _ in 0..<maxAttempts - 1 {
        do {
            return try await operation()
        } catch {
            guard !(error is CancellationError) else {
                throw error
            }
            let deadline = ContinuousClock().now.advanced(by: backoffStrategy.nextDuration())
            try await Task.sleep(
                until: deadline,
                tolerance: tolerance,
            )
        }
    }
    return try await operation()
}

/// Retries an async operation indefinitely with exponential backoff on failure.
///
/// This function continuously attempts to execute the provided operation with exponential
/// backoff and jitter between attempts. By default, the backoff starts at 100ms and doubles
/// with each retry. Unlike ``retry(maxAttempts:backoffFactor:backoffDuration:tolerance:operation:)``,
/// this function will continue retrying until the operation succeeds or the task is cancelled.
///
/// The retry loop will stop immediately if a `CancellationError` is thrown, propagating
/// the cancellation to the caller.
///
/// ## Example
///
/// ```swift
/// // Retry indefinitely with default exponential backoff
/// let connection = try await retryIndefinite {
///     try await establishDatabaseConnection()
/// }
///
/// // Retry with linear backoff (1s intervals)
/// let session = try await retryIndefinite(
///     backoffFactor: 1,
///     backoffDuration: .seconds(1)
/// ) {
///     try await createNetworkSession()
/// }
/// ```
/// 
/// - Parameters:
///   - backoffFactor: The multiplier applied to the backoff duration after each failed attempt.
///     Defaults to `2` for exponential backoff (100ms, 200ms, 400ms, etc.).
///   - backoffDuration: The initial backoff duration before the first retry.
///     Defaults to 100 milliseconds.
///   - tolerance: The allowable timing flexibility for the sleep operation between retries.
///     If `nil`, the system determines an appropriate tolerance. See ``Task/sleep(until:tolerance:clock:)``
///     for more details.
///   - operation: An async throwing closure that performs the operation to be retried.
/// - Returns: The successful result from the operation.
/// - Throws: `CancellationError` if the task is cancelled during retry.
/// - Important: This function will never stop retrying on its own. Ensure you have
///   appropriate cancellation mechanisms in place to avoid infinite retry loops.
nonisolated(nonsending)
public func retryIndefinite<Result, ErrorType: Error>(
    backoffFactor: Int = 2,
    backoffDuration: Duration = .milliseconds(100),
    tolerance: Duration? = nil,
    operation: () async throws(ErrorType) -> Result,
) async throws -> Result {
    var backoffStrategy = BackoffStrategy(factor: backoffFactor, initial: backoffDuration)
    while true {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let deadline = ContinuousClock().now.advanced(by: backoffStrategy.nextDuration())
            try await Task.sleep(
                until: deadline,
                tolerance: tolerance,
            )
        }
    }
}
