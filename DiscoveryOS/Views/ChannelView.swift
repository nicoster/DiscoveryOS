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
							if post.isSeparator {
								Divider()
							} else {
								PostListCellView(post:post, channel:channel)
							}
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
				ProgressView().frame(minWidth: 300)
			}
			
		}
		.task {
			if !firstLoaded {
				await loadMorePosts()
				firstLoaded = true
			}
		}
		//FIXME: not working for pull and refresh, why?
//		.refreshable {
//			refresh()
//		}
		.navigationTitle(channel.title)
#if os(macOS)
		.navigationSubtitle(channel.description)
		.toolbar {
			ToolbarItemGroup(placement: .navigation) {
				Button {
					Task {
						await refresh()
					}
				} label: {
					Image(systemName: "arrow.clockwise")
				}
			}
		}
#endif
	}
	
	func refresh() async {
		print("refresh posts..")
		posts = nil
		firstLoaded = false
		allLoaded = false
		page = 0
		
		await loadMorePosts()
		firstLoaded = true
	}
	
	func insertSeparator(posts : inout [Post]){
		var pos : Int?
		var min : Date = Date()
		for (i, post) in posts.enumerated() {
			if let date = post.lastReplyAt?.toDate(){
				if date < min {
					min = date
				} else {
					pos = i
					break
				}
			}
		}
		
		if let pos {
			posts.insert(.separator, at: pos)
		}
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
			#if os(macOS)
			insertSeparator(posts: &posts!)
			#endif
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
