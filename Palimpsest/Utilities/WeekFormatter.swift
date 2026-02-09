//
//  WeekFormatter.swift
//  Palimpsest
//
//  ISO 8601 week string for transfer folder naming.
//

import Foundation

enum WeekFormatter {
    static func weekString(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}
