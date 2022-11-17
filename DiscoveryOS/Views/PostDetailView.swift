//
//  PostDetailView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI
import MarkdownUI
import Kingfisher

struct PostDraft : Codable {
	let id : String?
	let title : String?
	let content : String?
}

struct ReplyView : View {
	@Binding var content : String
	@Binding var showingPanel : Bool
	
	let channel : Channel
	let postInfo : Post
	
	// see https://stackoverflow.com/a/56975728/590307
	init(content: Binding<String>, showingPanel: Binding<Bool>, channel: Channel, postInfo: Post, quote: Reply?) {
		self._content = content
		self._showingPanel = showingPanel
		self.channel = channel
		self.postInfo = postInfo
		
		if let quote {
			self.content = discuz.quoted(channel: channel, postInfo: postInfo, quote: quote)
		} else {
			self.content = ""
		}
	}
	
	var body: some View {
		ZStack {
			VStack {
				HStack {
					//FIXME: doesn't change icon accordingly. why?
					Image(systemName: content.isEmpty ? "bubble.left" : "ellipsis.bubble.fill")
					if let title = postInfo.title {
						Text(title)
					}
					Spacer()
					Button {
						Task {
							let okay = await discuz.postReply(fid: channel.id, tid: postInfo.id, content: content)
							if okay {
								content = ""
								showingPanel = false
							}
						}
					} label: {
						Label("Submit", systemImage: "paperplane")
					}
					//									.buttonStyle(.borderless)
					//FIXME: doesn't work, why?
					//									.disabled(replyContent.count < 10)
				}
				.padding([.top, .leading, .trailing], 8)
				ZStack {
					TextEditor(text: $content)
						.padding(0)
				}
			}
		}
		.font(.system(size: 14))
		.onAppear {
			if let draft = loadReplyDraft() {
				content = draft.content ?? ""
			}
		}
		.onDisappear {
			saveReplyDraft(draft: PostDraft(id:postInfo.id, title: postInfo.title, content: content))
		}
	}
	
	var draftKey : String {
		"draft-\(postInfo.id)"
	}

	func loadReplyDraft() -> PostDraft? {
		print("load draft ..")
		if let data = UserDefaults.standard.object(forKey: draftKey) as? Data {
			return try? JSONDecoder().decode(PostDraft.self, from: data)
		}
		return nil
	}
	
	func saveReplyDraft(draft: PostDraft) {
		if !content.isEmpty {
			print("save draft \(draft)")
			if let encoded = try? JSONEncoder().encode(draft) {
				UserDefaults.standard.set(encoded, forKey: draftKey)
			}
		}
	}
}

struct PostDetailView : View {
	let postInfo : Post
	let channel : Channel
	@State var mainPost: Reply?
	@State var replies : [Reply]?
	@State var mainPageLoaded : Bool = false
	@State var lastPage : Int = -1
	@State var page : Int = 1
	
	@State var showingPanel = false
	@State var replyContent : String = ""
	
	@State var titleAppear : Bool = true
	
	@State var bookmarked = false
	
	func hasMoreReplies() -> Bool {
		lastPage < 0 && replies?.count ?? 0 > 0
	}
	
	var body: some View {
		List {
			//			VStack(alignment: .leading, spacing: 5) {
			//				HStack {
			//					Text(postInfo.title)
			//						.font(.title)
			//						.lineLimit(3)
			//				}
			//			}
			
			
			if mainPageLoaded, let mainPost, let replies {
				ReplyCellView(showingReplyPanel: $showingPanel, replyContent: $replyContent, channel: channel, reply: mainPost, post: postInfo, first: true)
				
				ForEach (replies) { ReplyCellView(showingReplyPanel: $showingPanel, replyContent: $replyContent, channel: channel, reply: $0, post: postInfo) }
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
				}
				
				mainPageLoaded = true
			}
		}
		.toolbar {
			ToolbarItem(placement: .principal) {
				if let title = postInfo.title {
					Text(title)
						.font(.title)
				}
			}
			
			ToolbarItemGroup {
				
				Link(destination: URL(string: discuz.host + "viewthread.php?tid=\(postInfo.id)")!) {
					Image(systemName: "safari")
				}
				.foregroundColor(Color(NSColor.secondaryLabelColor))
				
				Button {
					Task {
						bookmarked = await discuz.bookmarkPost(id: postInfo.id)
					}
				} label: {
					Image(systemName: bookmarked ? "star.fill" : "star" )
				}
				.buttonStyle(.borderless)
				
				Button {
					showingPanel.toggle()
				} label: {
					Label("Reply", systemImage: replyContent.isEmpty ? "bubble.left" : "ellipsis.bubble.fill")
				}
				.keyboardShortcut(.defaultAction)
				.buttonStyle(.borderless)
				.help("Enter to reply")
				.floatingPanel(isPresented: $showingPanel, content: {
					ReplyView(content: $replyContent,
							  showingPanel: $showingPanel,
							  channel: channel,
							  postInfo: postInfo,
							  quote: nil)
				})
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
