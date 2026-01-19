//
//  RetryIndefiniteTests.swift
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

@Suite("Retry Indefinite Tests")
struct RetryIndefiniteTests {
    @Test func `Succeeds on first attempt`() async throws {
        var attemptCount = 0
        
        let result = try await retryIndefinite {
            attemptCount += 1
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 1)
    }
    
    @Test func `Retries until success`() async throws {
        var attemptCount = 0
        
        let result = try await retryIndefinite {
            attemptCount += 1
            if attemptCount < 5 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 5)
    }
    
    @Test func `Throws CancellationError immediately`() async throws {
        var attemptCount = 0
        
        await #expect(throws: CancellationError.self) {
            try await retryIndefinite {
                attemptCount += 1
                throw CancellationError()
            }
        }
        
        #expect(attemptCount == 1)
    }
    
    @Test func `Respects tolerance parameter`() async throws {
        var attemptCount = 0
        
        let result = try await retryIndefinite(tolerance: .milliseconds(50)) {
            attemptCount += 1
            if attemptCount < 3 {
                throw TestError.temporary
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 3)
    }
    
    @Test func `Handles task cancellation during retry`() async throws {
        var attemptCount = 0
        
        let task = Task {
            try await retryIndefinite {
                attemptCount += 1
                if attemptCount == 2 {
                    throw CancellationError()
                }
                throw TestError.temporary
            }
        }
        
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
