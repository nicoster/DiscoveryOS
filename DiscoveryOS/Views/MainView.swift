//
//  MainView.swift
//  DiscoveryOS
//
//  Created by Nick Xiao on 2022/10/30.
//

import Combine
import SwiftUI
import MarkdownUI
import Kingfisher


let myNetworkImage = MarkdownImageHandler(imageAttachment: { url in
	
	return Deferred {
		Future<NSTextAttachment, Never> { promise in
			KingfisherManager.shared.retrieveImage(with: ImageResource(downloadURL: url), completionHandler: { result in
				switch result {
				case .success(let value):
					let attachment = NSTextAttachment()
					attachment.image = value.image
					promise(.success(attachment))
				case .failure(let error):
					promise(.success(NSTextAttachment()))
				}
			})
		}
	}.eraseToAnyPublisher()
})


struct LoginView: View {
	@EnvironmentObject private var currentUser: CurrentUserStore

	@State var user : String = ""
	@State var pass : String = ""
	@State var logining : Bool = false
	
	@State var userInfo : User?
	@State var loaded : Bool = false
	
	
	var body : some View {
		if currentUser.verified {
			profile
		} else {
			loginForm
		}
	}
	
	func login() {
		logining = true
		let _ = currentUser.verifyCred(u: user, p: pass)
		logining = false
	}
	
	func logout() {
		pass = ""
		currentUser.logout()
	}
	
	var loginForm : some View {
		Form {
			VStack {
				TextField("", text: $user, prompt: Text("Username"))
					.frame(width: 200)
				SecureField("", text: $pass, prompt: Text("Password"))
					.frame(width: 200)

			}
			
			Button {
				login()
			} label: {
				Text("Sign in")
			}
			.disabled(logining || user.count == 0 || pass.count == 0)
		}
	}
	
	var profile : some View {
		VStack {
			if currentUser.verified {
				if let avatar = userInfo?.avatar {
					KFImage.url(URL(string: avatar))
						.resizable()
						.fade(duration: 0.25)
						.scaledToFill()
						.frame(width: 48, height: 48)
						.mask(RoundedRectangle(cornerRadius: 8))
				}
				
				Text(currentUser.user ?? "")
				Button {
					logout()
				} label: {
					Text("Sign Out")
				}
				.buttonStyle(.borderless)
			}
		}
		.task {
			if !loaded, let u = currentUser.user {
				userInfo = await discuz.loadUser(name: u)
				loaded = true
			}
		}
	}
}

struct MainView: View {
	@EnvironmentObject private var currentUser: CurrentUserStore
	
	@State var channels : [Channel]?
	@State var loaded : Bool = false
	
	//FIXME: if it's not a @State, the compilier complains "Cannot pass immutable value as inout argument: 'self' is immutable"
	// I got the feeling that the sharedSubject can be removed by utilizing SwiftUI builtin facilities.
	@State var cancellables : Set<AnyCancellable> = []
	
	var body: some View {
		NavigationView {
			List () {
				Section(header: Text("Home")) {
					if loaded {
						if let channels {
							ForEach(channels) { channel in
								NavigationLink(channel.title) {
									ChannelView(channel:channel)
								}
								.badge(channel.newPosts ?? 0)
							}
						}
						
					} else {
						ProgressView()
					}
				}
				
				Section(header: Text("Account")) {
					NavigationLink(destination: LoginView()) {
						Label("用户", systemImage: "person.circle")
					}
					
					if currentUser.verified {
						NavigationLink(destination: ChannelView(channel: Channel(id:"BOOKMARK", title: "我的收藏", description: "", newPosts: 0))) {
							Label("收藏", systemImage: "star")
						}
					}
				}
			}
			.listStyle(.sidebar)
			.frame(minWidth: 200)
			#if os(macOS)
			.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					Button(action:{
						NSApp.keyWindow?.initialFirstResponder?.tryToPerform(
							#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
					}, label: {
						Image(systemName: "sidebar.left")
					})
				}
			}
			#endif
			
		}
		.onAppear {
			listen()
		}
		.task {
			if !loaded {
				channels = await discuz.loadChannels()
				loaded = true
			}
		}
	}
	
	func listen() {
		print("start listening on sharedSubject")
		sharedSubject
			.receive(on: RunLoop.main)
			.sink { event in
				print("sink \(event)")
				switch event {
				case .login, .logout:
					Task {
						channels = await discuz.loadChannels()
					}
				}
			}
			.store(in: &cancellables)
	}
}
