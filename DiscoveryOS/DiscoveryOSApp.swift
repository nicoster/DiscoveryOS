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
		
//		URLSessionConfiguration.default.connectionProxyDictionary = [
//		  kCFNetworkProxiesHTTPEnable: true,
//		  kCFNetworkProxiesHTTPProxy: "localhost",
//		  kCFNetworkProxiesHTTPPort: "8080",
//		  kCFNetworkProxiesHTTPSEnable: true,
//		  kCFNetworkProxiesHTTPSProxy: "localhost",
//		  kCFNetworkProxiesHTTPSPort: "8080"
//		]
	}
	var body: some Scene {
		WindowGroup {
			MainView()
				.environmentObject(CurrentUserStore.shared)
				.font(.system(size: 14))
		}
		
	}
}
