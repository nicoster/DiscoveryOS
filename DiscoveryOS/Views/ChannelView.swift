//
//  ChannelView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI

struct ChannelView: View {
	let channel : Channel
	@State var posts : [Post]?
	@State var firstLoaded : Bool = false
	@State var page : Int = 0
	@State var allLoaded : Bool = false
	
	func hasMorePosts() -> Bool {
		!allLoaded
	}
	
	var body: some View {
		NavigationView {
			
			if firstLoaded {
				List {
					if let posts {
						ForEach (posts) { post in
							PostListCellView(post:post, channel:channel)
						}
					}
					
					if hasMorePosts() {
						HStack {
							Spacer()
							ProgressView()
								.onAppear {
									Task { await loadMorePosts() }
								}
							Spacer()
						}
					}
				}
				.listStyle(.inset)
				.frame(minWidth: 400, idealWidth: 500)
			} else {
				ProgressView().frame(minWidth: 400)
			}
			
		}
		.task {
			if !firstLoaded {
				await loadMorePosts()
				firstLoaded = true
			}
		}
		.refreshable {
			print("refresh..")
			posts = nil
			firstLoaded = false
			allLoaded = false
			page = 0
			
			await loadMorePosts()
			firstLoaded = true
		}
		.navigationTitle(channel.title)
#if os(macOS)
		.navigationSubtitle(channel.description)
#endif
	}
	
	func loadMorePosts() async {
		page += 1
		let more : [Post]
		if channel.id == "BOOKMARK" {
			more = await discuz.loadBookmarks(page: page)
		} else {
			more = await discuz.loadPosts(fid: channel.id, page: page)
		}
		
		if posts == nil {
			posts = more
			return
		}
		
		var appended = false
		for item in more {
			if posts?.first(where:{$0.id == item.id}) != nil {
				continue
			}
			posts?.append(item)
			appended = true
		}
		
		if !appended {
			allLoaded = true
		}
	}
}
