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

public struct BackoffStrategy {
    var current: Duration
    let factor: Int
    var hasOverflown = false

    public init(factor: Int = 2, initial: Duration = .milliseconds(100)) {
        precondition(initial >= .zero, "Initial must be greater than or equal to 0")
        self.current = initial.jitter()
        self.factor = factor
    }

    public mutating func nextDuration() -> Duration {
        if hasOverflown {
            return Duration(secondsComponent: .max, attosecondsComponent: .max)
        } else {
            let components = current.components

            // Multiply seconds component
            let (newSeconds, secondsOverflow) = components.seconds.multipliedReportingOverflow(by: Int64(factor))

            // Multiply attoseconds component
            let (newAttoseconds, attosecondsOverflow) = components
                .attoseconds
                .multipliedReportingOverflow(by: Int64(factor))

            // Check for overflow in either component
            if secondsOverflow || attosecondsOverflow {
                self.hasOverflown = true
                return nextDuration()
            }

            // Handle attoseconds overflow into seconds (if attoseconds >= 10^18)
            let additionalSeconds = newAttoseconds / attosecondsPerSecond
            let finalAttoseconds = newAttoseconds % attosecondsPerSecond

            // Add overflow from attoseconds to seconds
            let (finalSeconds, additionOverflow) = newSeconds.addingReportingOverflow(additionalSeconds)

            if additionOverflow {
                self.hasOverflown = true
                return nextDuration()
            }

            let duration = Duration(secondsComponent: finalSeconds, attosecondsComponent: finalAttoseconds).jitter()

            defer {
                current = duration
            }
            return current
        }
    }
}
