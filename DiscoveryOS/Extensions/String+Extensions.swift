//
//  String+Extensions.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/21.
//

import Foundation


extension String {
	func from(_ start: Int) -> String {
		String(self[index(startIndex, offsetBy: start)...])
	}
}
