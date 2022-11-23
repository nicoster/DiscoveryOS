//
//  ReplyCellView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/11/2.
//

import SwiftUI
import Kingfisher
import MarkdownUI

import WebKit

#if os(macOS)

struct WebView : NSViewRepresentable {
	let html : String
	func makeNSView(context: Context) -> WKWebView
	{
		return WKWebView()
	}
	func updateNSView(_ nsView: WKWebView, context: Context) {
		nsView.loadHTMLString(html, baseURL: URL(string:discuz.host))
		let cssString = "body { font-family: Verdana, Helvetica, Arial, sans-serif; font-size: 14px; color: #f00 }"
		let jsString = "var style = document.createElement('style'); style.innerHTML = '\(cssString)'; document.head.appendChild(style);"
		nsView.evaluateJavaScript(jsString, completionHandler: nil)
	}
}

#endif

struct ReplyCellView : View {
	let channel : Channel
	let reply : Reply
	let post : Post
	let first : Bool
//	@State private var showingPopover = false
	@State var bookmarked = false
	
	@Binding var showingReplyPanel : Bool
	@Binding var replyContent : String
	
	init(showingReplyPanel: Binding<Bool>, replyContent : Binding<String>, channel: Channel, reply: Reply, post: Post, first: Bool = false) {
		self._showingReplyPanel = showingReplyPanel
		self._replyContent = replyContent
		
		self.channel = channel
		self.reply = reply
		self.post = post
		self.first = first
	}
	
	var body : some View {
		if !first {
			Divider()
		}
		
		HStack(alignment: .top) {
			
			if let avatar = reply.author.avatar {
				KFImage.url(URL(string: avatar))
					.resizable()
					.fade(duration: 0.25)
					.scaledToFill()
					.frame(width: 40, height: 40)
					.mask(RoundedRectangle(cornerRadius: 4))
			}
			VStack(alignment: .leading, spacing: 6) {
				HStack {
					if let username = reply.author.name {
						Text(username)
					}
					
					if let created = reply.at {
						Text(created.toDate()?.fromNow() ?? created)
					}
					
					if let index = reply.seq {
						Text("\(index)#")
					}
					
					Button {
						print("\n\nbody +++++++++++++++++++++++++++++++++ \(reply.body.count)")
						print(reply.body)
						
						print("markdown --------------------------------- \(reply.markdown.count)")
						print(reply.markdown)
						
					} label: {
						Image(systemName: "list.bullet.rectangle.fill")
					}
					.buttonStyle(.borderless)
					
					Button {
						showingReplyPanel.toggle()
						if showingReplyPanel {
							replyContent = discuz.quoted(channel: channel, postInfo: post, quote: reply) + replyContent
						}
					} label: {
						Image(systemName: replyContent.isEmpty ? "bubble.left" : "ellipsis.bubble.fill")
					}
					.keyboardShortcut(.defaultAction)
					.buttonStyle(.borderless)
					.help("Enter to reply")
					
					//					Button {
					//						showingPopover = true
					//					} label: {
					//						Image(systemName: "airplane")
					//					}
					//					.buttonStyle(.borderless)
					//					.popover(isPresented: $showingPopover) {
					//						//											WebView(html:reply.body)
					//						Text(reply.body)
					//							.frame(minWidth: 500)
					//							.lineLimit(nil)
					//
					//					}
					
				}
#if os(macOS)
				.foregroundColor(Color(NSColor.tertiaryLabelColor))
#endif
				
				Markdown(reply.markdown, baseURL: URL(string:discuz.host)!)
					.markdownStyle(
						MarkdownStyle(font: .system(size: 14))
					)
				
			}
		}
	}
}
