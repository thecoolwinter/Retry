//
//  Duration+Jitter.swift
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

extension Duration {
    func jitter(_ span: ClosedRange<Double> = 0.8...1.0) -> Duration {
        let jitterMultiplier = Double.random(in: span)
        let jitteredSeconds = Double(components.seconds) * jitterMultiplier
        var jitteredAttoseconds = Double(components.attoseconds) * jitterMultiplier
        if jitteredSeconds < 1.0 {
            jitteredAttoseconds += jitteredSeconds * Double(attosecondsPerSecond)
        }
        return Duration(
            secondsComponent: Int64(jitteredSeconds),
            attosecondsComponent: Int64(jitteredAttoseconds)
        )
    }
}
