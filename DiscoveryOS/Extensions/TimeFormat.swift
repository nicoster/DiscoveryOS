//
//  TimeFormat.swift
//  V2exOS
//
//  Created by isaced on 2022/7/24.
//

import Foundation

extension Date {
	
	func fromNow() -> String {
		// ask for the full relative date
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .full
		formatter.locale = Locale.init(identifier: Locale.preferredLanguages.first!)
		
		// get exampleDate relative to the current date
		let relativeDate = formatter.localizedString(for: self, relativeTo: Date.now)
		
		return relativeDate
	}
	
}

extension String {
	func toDate() -> Date? {
		let dateFormatterUK = DateFormatter()
		dateFormatterUK.dateFormat = "yyyy-MM-dd HH:mm"
		
		//		let stringDate = "2022-11-14 14:3"
		return dateFormatterUK.date(from: self)
	}
	
}

extension String {
	func formatDate() -> String? {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		guard let date = dateFormatter.date(from: self) else { return self }

		let calendar = Calendar.current
		let year = calendar.component(.year, from: date)
		let month = calendar.component(.month, from: date)
		let day = calendar.component(.day, from: date)
		let today = Date()

		if year == calendar.component(.year, from: today) {
			if month == calendar.component(.month, from: today) {
				if day == calendar.component(.day, from: today) {
					return nil
				} else if day == calendar.component(.day, from: today.addingTimeInterval(-86400)) {
					return "昨天"
				} else {
					return "\(day)日"
				}
			} else {
				return "\(month)-\(day)"
			}
		} else {
			return "\(year)-\(month)-\(day)"
		}
	}
}
