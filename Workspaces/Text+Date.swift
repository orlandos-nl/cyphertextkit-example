//
//  TextDate.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI

private let hourFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let weekdayFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let weekdayTimeFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "EEE HH:mm"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let dayMonthFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "d MMM"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let dayMonthTimeFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "d MMM HH:mm"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let dayMonthYearFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yy"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

private let dayMonthYearTimeFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yy HH:mm"
    formatter.locale = Locale(identifier: "en-EN")
    return formatter
}()

extension Text {
    init?(date: Date, requiresTime: Bool = false) {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            self.init(hourFormatter.string(from: date))
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
            if requiresTime {
                self.init(weekdayTimeFormatter.string(from: date))
            } else {
                self.init(weekdayFormatter.string(from: date))
            }
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            // Longer than a week ago, but this year
            if requiresTime {
                self.init(dayMonthTimeFormatter.string(from: date))
            } else {
                self.init(dayMonthFormatter.string(from: date))
            }
        } else {
            // Different year
            if requiresTime {
                self.init(dayMonthYearTimeFormatter.string(from: date))
            } else {
                self.init(dayMonthYearFormatter.string(from: date))
            }
        }
    }
}
