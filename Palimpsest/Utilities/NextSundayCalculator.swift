//
//  NextSundayCalculator.swift
//  Palimpsest
//
//  Calculates the next Sunday for the ritual transfer.
//

import Foundation

enum NextSundayCalculator {
    /// Returns the next Sunday session (if today is Sunday, the one in 7 days) and days until.
    static func nextSunday(from date: Date = Date()) -> (date: Date, daysUntil: Int) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1. If Sunday, next session is in 7 days. Otherwise 8 - weekday.
        let daysUntil = weekday == 1 ? 7 : 8 - weekday
        guard let next = calendar.date(byAdding: .day, value: daysUntil, to: date) else {
            return (date, 0)
        }
        return (next, daysUntil)
    }
}
