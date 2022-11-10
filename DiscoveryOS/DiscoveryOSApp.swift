//
//  DiscoveryOSApp.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/10/30.
//

import SwiftUI
import Kingfisher

var discuz = DiscuzAPI()

@main
struct DiscoveryOSApp: App {
	init(){
		KingfisherManager.shared.downloader.sessionConfiguration = URLSessionConfiguration.default
	}
	var body: some Scene {
		WindowGroup {
			MainView()
				.environmentObject(CurrentUserStore.shared)
		}
		
	}
}
