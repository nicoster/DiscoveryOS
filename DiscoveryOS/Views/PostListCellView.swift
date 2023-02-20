//
//  PostListCellView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI
import Kingfisher
import MarkdownUI

struct PostListCellView : View {
	let post : Post
	let channel : Channel
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

					HStack(spacing: 4) {
						if let username = post.lastReplyBy ?? post.author {
							Text(username)
								.lineLimit(1)
								.truncationMode(.tail)
							Text("•")
						}

						if let lastModified = post.lastReplyAt ?? post.at {
							Text(lastModified.toDate()?.fromNow() ?? lastModified)
								.lineLimit(1)
								.truncationMode(.tail)
						}

						Spacer()

						if let author = post.author, let at = post.at {
							Group {
								Text(author)
									.lineLimit(1)
									.truncationMode(.tail)
									.font(.system(size: 11))
									.foregroundColor(.white)
									.padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
									.background(RoundedRectangle(cornerRadius: 4).fill(.primary))

								if let datestr = at.formatDate() {
									Text(datestr)
										.lineLimit(1)
										.truncationMode(.tail)
										.font(.system(size: 11))
										.foregroundColor(.white)
										.padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
										.background(RoundedRectangle(cornerRadius: 4).fill(.primary))
								}
							}
						}
					}
					.foregroundColor(Color(NSColor.tertiaryLabelColor))
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
