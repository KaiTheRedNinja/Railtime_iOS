//
//  RateLimiter.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 15/9/26.
//

import Foundation

actor RateLimiter {
    private let interval: Duration
    private var lastRequestTime: ContinuousClock.Instant?

    private let clock = ContinuousClock()

    init(requestsPerSecond: Double) {
        self.interval = .milliseconds(
            Int((1.0 / requestsPerSecond) * 1000.0)
        )
    }

    func acquire() async {
        if let lastRequestTime {
            let nextAllowed = lastRequestTime + interval

            if clock.now < nextAllowed {
                // we set the last request time here to avoid the double-entrancy problem
                self.lastRequestTime = nextAllowed
                try? await Task.sleep(until: nextAllowed, clock: clock)
            }
        }
        lastRequestTime = clock.now

        print("[RATE LIMITER] Approved at \(Date.now)")
    }
}
