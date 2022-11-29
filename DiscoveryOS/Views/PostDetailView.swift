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

struct DraftView : View {
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
					//FIXME: doesn't work, why?
					.disabled(content.count < 10)
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
	let pageSize = discuz.pageSize
	
	@State var replies : [Reply] = []
	@State var lastPage : Int = -1	// the last page
	@State var tailPage : Int = 1 	// current last page
	@State var page : Int = 1
	
	@State var showingPanel = false
	@State var replyContent : String = ""
	
	@State var titleAppear : Bool = true
	
	@State var bookmarked = false
	
	@State var loading : Bool = false {
		willSet {
			print("will set loading:\(newValue) last: \(lastPage)")
		}
	}
	
	func hasMoreReplies() -> Bool {
		lastPage < 0 && replies.count > 0
	}
	
	var body: some View {
		List {
			
			if !replies.isEmpty {
				
				ForEach (replies) { reply in
					if reply.isPlaceholder {
						Divider()
						HStack{
							Spacer(minLength: 10)
							Markdown(reply.pageSlots)
								.background(RoundedRectangle(cornerRadius: 4).fill(.tertiary).padding(-4))
								.environment(
									\.openURL,
									 OpenURLAction { url in
										 let page = Int(url.absoluteString.from(5))!
										 print("page:\(page)")
										 updateReplySlot(page: page)
										 loadMoreReplies(page: page)
										 return .handled
									 }
								)
							Spacer(minLength: 10)
						}
					} else if reply.isSpinner {
						Divider()
						ProgressView()
							.alignmentGuide(HorizontalAlignment.center) { _ in 0}
					} else {
						ReplyCellView(showingReplyPanel: $showingPanel, replyContent: $replyContent, channel: channel, reply: reply, post: postInfo, first: reply == replies.first)
					}
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
							let total = (postInfo.replies + pageSize) / pageSize
							print("total page: \(total) replies: \(replies.count)")
							if replies.count <= pageSize && total - page > 8 {
								loadMoreReplies(page: page + total - 5)
							} else {
								loadMoreReplies(page: tailPage + 1)
							}
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
			if replies.isEmpty {
				let replies = await discuz.loadReplies(tid: postInfo.id)
				if replies.count < pageSize {
					lastPage = 1
				}
				
				self.replies = replies
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
				
				Link(destination: URL(string: postInfo.link)!) {
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
					DraftView(content: $replyContent,
							  showingPanel: $showingPanel,
							  channel: channel,
							  postInfo: postInfo,
							  quote: nil)
				})
			}
		}

	}
	
	func updateReplySlot(page: Int) {
		if let pos = findReplySlot(page: page) {
			let old = replies.remove(at:pos)
//			print("old:\(old.seq)+\(old.len)")
			var new : [Reply]?
			
			let maxPage = old.len / pageSize
			switch (page - old.seq / pageSize) {
			case maxPage:
				if maxPage == 1 {
					new = [.spinner]
				} else {
					new = [.placeholder(seq: old.seq, len: old.len - pageSize), .spinner]
				}
			case 1:
				new = [.spinner, .placeholder(seq: old.seq + pageSize, len: old.len - pageSize)]
			case let slot:
				new = [
					.placeholder(seq: old.seq, len: (slot - 1) * pageSize),
					.spinner,
					.placeholder(seq: old.seq + slot * pageSize, len: (maxPage - slot) * pageSize)
				]
			}
			
			if let new {
				replies.insert(contentsOf: new, at: pos)
			}
		}
	}
	
	func findReplySlot(page: Int) -> Int? {
		for (pos, reply) in replies.enumerated() {
//			print("len:\(len), page:\(page)")
			if reply.seq < page * pageSize && reply.seq + reply.len >= page * pageSize {
				if reply.len % pageSize != 0 {
					print("found wrong reply: \(reply)")
					return nil
				}
				return pos
			}
		}
		
		print("found no reply, page:\(page)")
		return nil
	}

	func loadMoreReplies(page : Int) {
		if loading {
			print("is loading \(self.page), ignore load \(page)")
			return
		}
		
		loading = true
		
		Task {
			defer {
				loading = false
			}
			
			if lastPage > 0 && lastPage <= page {
				print("loaded too many page \(page) last: \(lastPage)")
				return
			}
			
			self.page = page
			if page > self.tailPage {
				self.tailPage = page
			}
			
			let more = await discuz.loadReplies(tid: postInfo.id, page: page)
			
			if more.count < pageSize {
				lastPage = page
			} else {
				for item in more { // if replies are already loaded, it means EOF
					if replies.first(where:{$0.id == item.id}) != nil {
						print("\(item.seq)# already exists, stop loading")
						lastPage = page
						return
					}
				}
			}
			
			if let first = more.first,
			   var pos = replies.lastIndex(where: {$0.seq < first.seq}) {
				let val = replies[pos]
				print("pos:\(pos) val:\(val.seq)")
				
				let seq = val.seq + val.len
				
				pos += 1
				
				if pos != replies.endIndex && replies[pos].isSpinner {
					replies.remove(at: pos)
				}
				
//				print("val:\(val)")
//				print("first:\(first)")
				if first.seq > seq {
					replies.insert(
						.placeholder(seq: seq, len: first.seq - seq),
						at: pos
					)
					pos += 1
				}
				
				withAnimation {
					replies.insert(contentsOf: more, at: pos)
				}
			}
			
//			print("count \(replies.count)")
			
//			replies.forEach { print("\($0.seq), \($0.len)") }
		}
		
	}
}
