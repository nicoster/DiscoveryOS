//
//  PostListCellView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI
import Kingfisher

struct PostListCellView : View {
	let post : Post
	let channel : String
	@State var user : User?
	@State var loaded : Bool = false
	
	var body : some View {
		NavigationLink {
			PostDetailView(postInfo: post, channel: channel)
//				.navigationTitle("\(channel) - \(post.title)")
		} label: {
			HStack {
				if let avatar = user?.avatar {
					KFImage.url(URL(string: avatar))
						.resizable()
						.fade(duration: 0.25)
						.scaledToFill()
						.frame(width: 48, height: 48)
						.mask(RoundedRectangle(cornerRadius: 8))
				}
				
				VStack(alignment: .leading, spacing: 6) {
					
					Text(post.title)
						.lineLimit(2)
					
					HStack() {
						
						if let username = post.lastReplyBy ?? post.author {
							Text(username)
							Text("•")
						}
						
						if let lastModified = post.lastReplyAt ?? post.created {
							Text(lastModified)
						}
					}
					.foregroundColor(.gray)
				}
				
				
				//				Spacer()
				//				Text(String(post.replies))
				//					.foregroundColor(.white)
				//					.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
				//					.background(RoundedRectangle(cornerRadius: 4).fill(.gray))
				
			}
			.badge(post.replies)
#if os(macOS)
			.foregroundColor(Color(NSColor.labelColor))
#endif
			.task {
				if let name = post.lastReplyBy {
					if !loaded {
						user = await discuz.loadUser(name: name)
						loaded = true
					}
				}
			}
		}
	}
}
