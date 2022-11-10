//
//  PostDetailView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI
import MarkdownUI
import Kingfisher

struct PostDetailView : View {
	let postInfo : Post
	let channel : String
	@State var mainPost: Reply?
	@State var replies : [Reply]?
	@State var mainPageLoaded : Bool = false
	@State var lastPage : Int = -1
	@State var page : Int = 1
	
	@State var titleAppear : Bool = true
	
	func hasMoreReplies() -> Bool {
		lastPage < 0 && replies?.count ?? 0 > 0
	}
	
	var body: some View {
		List {
			VStack(alignment: .leading, spacing: 5) {
				HStack {
					Text(postInfo.title)
						.font(.title)
						.lineLimit(3)
						//FIXME: this only works for one shot
						.onDisappear {
							titleAppear = false
							print("\(postInfo.title) disappear..")
						}
						.onAppear {
							titleAppear = true
							print("\(postInfo.title) appear..")
							
						}
						.navigationTitle(titleAppear ? "\(channel)" : "\(channel) - \(postInfo.title)")
				}
			}
			
			
			if mainPageLoaded, let mainPost, let replies {
				ReplyCellView(reply: mainPost, postId: postInfo.id, first: true)

				ForEach (replies) { reply in
					ReplyCellView(reply: reply)
				}
			} else {
				HStack {
					Spacer()
					ProgressView()
					Spacer()
				}
			}
			
			if hasMoreReplies() {
				Spacer()
				HStack {
					Spacer()
					ProgressView()
						.onAppear {
							loadMoreReplies()
						}
					Spacer()
				}
			}
		}
		.textSelection(.enabled)
		#if os(macOS)
		.foregroundColor(Color(NSColor.labelColor))
		#endif
		.task {
			if !mainPageLoaded {
				replies = await discuz.loadReplies(tid: postInfo.id)
				mainPost = replies?.first
				if let replies {
					if replies.count < discuz.pageSize - 3 {
						lastPage = 1
					}
					self.replies = Array(replies.dropFirst())
//					self.replies = replies
				}
				
				mainPageLoaded = true
			}
		}
	}
	
	func loadMoreReplies() {
		Task {
			page += 1
			if lastPage > 0 && lastPage <= page {
				print("loaded too many page \(page) last: \(lastPage)")
				return
			}
			
			let more = await discuz.loadReplies(tid: postInfo.id, page: page)
			
			for item in more {
				if let replies, replies.first(where:{$0.id == item.id}) != nil {
					lastPage = page
					return
				}
			}
			replies?.append(contentsOf: more)
		}
	}
}
