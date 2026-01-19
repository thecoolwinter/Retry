//
//  BackoffStrategyTests.swift
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

@Suite
struct BackoffStrategyTests {
    @Test func `Initializes with default values`() {
        var strategy = BackoffStrategy()
        
        let duration = strategy.nextDuration()
        
        // First duration should be close to initial value (100ms with jitter)
        #expect(duration >= .milliseconds(80))
        #expect(duration <= .milliseconds(100))
    }
    
    @Test func `Initializes with custom values`() {
        var strategy = BackoffStrategy(factor: 3, initial: .milliseconds(200))
        
        let duration = strategy.nextDuration()
        
        // First duration should be close to 200ms (with 0.8-1.0 jitter)
        #expect(duration >= .milliseconds(160))
        #expect(duration <= .milliseconds(200))
    }
    
    @Test func `Applies exponential backoff`() {
        var strategy = BackoffStrategy(factor: 2, initial: .milliseconds(100))
        
        let first = strategy.nextDuration()
        let second = strategy.nextDuration()
        let third = strategy.nextDuration()
        
        // Each should be roughly double the previous (accounting for jitter)
        // First: ~100ms, Second: ~200ms, Third: ~400ms
        #expect(first >= .milliseconds(80))
        #expect(first <= .milliseconds(100))
        
        #expect(second >= .milliseconds(128))
        #expect(second <= .milliseconds(200))
        
        #expect(third >= .milliseconds(204))
        #expect(third <= .milliseconds(400))
    }
    
    @Test func `Applies jitter to backoff duration`() {
        var strategy = BackoffStrategy(factor: 2, initial: .milliseconds(1000))
        
        var durations: [Duration] = []
        for _ in 0..<10 {
            strategy = BackoffStrategy(factor: 2, initial: .milliseconds(1000))
            durations.append(strategy.nextDuration())
        }
        
        // Check that we got different values due to jitter
        let uniqueDurations = Set(durations)
        #expect(uniqueDurations.count > 1)
        
        // All values should be within jitter range (0.8-1.0)
        for duration in durations {
            #expect(duration >= .milliseconds(800))
            #expect(duration <= .milliseconds(1000))
        }
    }
    
    @Test func `Handles overflow gracefully`() {
        var strategy = BackoffStrategy(
            factor: 2,
            initial: Duration(secondsComponent: Int64.max / 2, attosecondsComponent: 0)
        )
        
        // This should overflow
        let _ = strategy.nextDuration()
        let overflowDuration = strategy.nextDuration()
        
        // After overflow, should return max duration
        #expect(overflowDuration == Duration(secondsComponent: .max, attosecondsComponent: .max))
    }
    
    @Test func `Stays at max after overflow`() {
        var strategy = BackoffStrategy(
            factor: 2,
            initial: Duration(secondsComponent: Int64.max / 2, attosecondsComponent: 0)
        )
        
        // Trigger overflow
        let _ = strategy.nextDuration()
        let _ = strategy.nextDuration()
        
        // All subsequent calls should return max
        let first = strategy.nextDuration()
        let second = strategy.nextDuration()
        let third = strategy.nextDuration()
        
        let maxDuration = Duration(secondsComponent: .max, attosecondsComponent: .max)
        #expect(first == maxDuration)
        #expect(second == maxDuration)
        #expect(third == maxDuration)
    }
    
    @Test func `Handles attoseconds overflow into seconds`() {
        var strategy = BackoffStrategy(
            factor: 2,
            initial: Duration(secondsComponent: 0, attosecondsComponent: 600_000_000_000_000_000)
        )
        
        let first = strategy.nextDuration()
        let second = strategy.nextDuration()
        
        // Verify durations are calculated correctly even when attoseconds overflow
        #expect(first >= .zero)
        #expect(second >= first)
    }
    
    @Test func `Works with zero initial duration`() {
        var strategy = BackoffStrategy(factor: 2, initial: .zero)
        
        let duration = strategy.nextDuration()
        
        #expect(duration == .zero)
    }
    
    @Test func `Increases duration with custom factor`() {
        var strategy = BackoffStrategy(factor: 5, initial: .milliseconds(10))
        
        let first = strategy.nextDuration()
        let second = strategy.nextDuration()
        
        // Second should be roughly 5x first (accounting for jitter)
        #expect(first >= .milliseconds(8))
        #expect(first <= .milliseconds(10))

        #expect(second >= .milliseconds(32))
        #expect(second <= .milliseconds(50))
    }
    
    @Test func `Maintains state across multiple calls`() {
        var strategy = BackoffStrategy(factor: 2, initial: .milliseconds(100))
        
        let first = strategy.nextDuration()
        let second = strategy.nextDuration()
        let third = strategy.nextDuration()
        
        // Each call should increase the internal state
        #expect(third > second)
        #expect(second > first)
    }
}
