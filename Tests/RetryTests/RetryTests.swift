//
//  RetryTests.swift
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

import Testing
@testable import Retry

enum TestError: Error, Equatable {
    case temporary
    case permanent
    case specific(String)
}

@Suite
struct RetryTests {
    @Test func `Succeeds on first attempt`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 3) {
            attemptCount += 1
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 1)
    }
    
    @Test func `Succeeds on second attempt after one failure`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 3) {
            attemptCount += 1
            if attemptCount == 1 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 2)
    }
    
    @Test func `Succeeds on final attempt`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 3) {
            attemptCount += 1
            if attemptCount < 3 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 3)
    }
    
    @Test func `Throws error after max attempts exhausted`() async throws {
        var attemptCount = 0
        
        await #expect(throws: TestError.permanent) {
            try await retry(maxAttempts: 3) {
                attemptCount += 1
                throw TestError.permanent
            }
        }
        
        #expect(attemptCount == 3)
    }
    
    @Test func `Immediately throws CancellationError without retry`() async throws {
        var attemptCount = 0
        
        await #expect(throws: CancellationError.self) {
            try await retry(maxAttempts: 5) {
                attemptCount += 1
                throw CancellationError()
            }
        }
        
        #expect(attemptCount == 1)
    }
    
    @Test func `Works with single attempt`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 1) {
            attemptCount += 1
            return 42
        }
        
        #expect(result == 42)
        #expect(attemptCount == 1)
    }
    
    @Test func `Works with single attempt that fails`() async throws {
        var attemptCount = 0
        
        await #expect(throws: TestError.permanent) {
            try await retry(maxAttempts: 1) {
                attemptCount += 1
                throw TestError.permanent
            }
        }
        
        #expect(attemptCount == 1)
    }
    
    @Test func `Respects tolerance parameter`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 2, tolerance: .milliseconds(50)) {
            attemptCount += 1
            if attemptCount == 1 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 2)
    }
    
    @Test func `Works with different result types`() async throws {
        struct ComplexResult: Equatable {
            let value: Int
            let name: String
        }
        
        let result = try await retry(maxAttempts: 1) {
            ComplexResult(value: 100, name: "test")
        }
        
        #expect(result.value == 100)
        #expect(result.name == "test")
    }
    
    @Test func `Applies backoff between retries`() async throws {
        var attemptCount = 0
        var timestamps: [ContinuousClock.Instant] = []
        
        let result = try await retry(maxAttempts: 3) {
            attemptCount += 1
            timestamps.append(.now)
            if attemptCount < 3 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(timestamps.count == 3)
        
        // Verify there's a delay between attempts (at least some time has passed)
        if timestamps.count >= 2 {
            let firstDelay = timestamps[1] - timestamps[0]
            #expect(firstDelay > .zero)
        }
    }

    @Test func `Retry with real async operation`() async throws {
        actor Counter {
            var count = 0
            func increment() -> Int {
                count += 1
                return count
            }
        }
        
        let counter = Counter()
        
        let result = try await retry(maxAttempts: 3) {
            let count = await counter.increment()
            if count < 2 {
                throw TestError.temporary
            }
            return "attempt \(count)"
        }
        
        #expect(result == "attempt 2")
    }
    
    @Test func `Retry with network-like operation`() async throws {
        var attemptCount = 0
        
        let result = try await retry(maxAttempts: 5) {
            attemptCount += 1
            
            // Simulate network failure on first 2 attempts
            if attemptCount <= 2 {
                throw TestError.specific("Network timeout")
            }
            
            return ["data": "value"]
        }
        
        #expect(result["data"] == "value")
        #expect(attemptCount == 3)
    }
}
