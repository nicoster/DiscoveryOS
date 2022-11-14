//
//  CurrentUserStore.swift
//

import Foundation
import SwiftUI
import KeychainAccess
import Combine

public enum EventType {
	case login
	case logout
}

//FIXME: there must be a right way to notify the views to update
public let sharedSubject = PassthroughSubject<EventType, Never>()

@MainActor public class CurrentUserStore: ObservableObject {
	
	public static let shared = CurrentUserStore()
	
	@Published public private(set) var user: String?
	@State private var pass: String?
	
	@Published public var verified : Bool = false {
		didSet {
			print("verified:\(verified)")
		}
	}
	
	let keychain = Keychain(service: "com.nickr.discoveryOS")
	let KeychainCredKey = "cred"
	
	public init() {
		
#if DEBUG
		if let data = UserDefaults.standard.object(forKey:KeychainCredKey) as? Data,
		   let tokens = String(data: data, encoding: .utf8)?.components(separatedBy: ":"),
		   tokens.count == 2,
		   verifyCred(u: tokens[0], p: tokens[1], save:false) {
			return
		}
#endif
		
		if let cred = keychain[KeychainCredKey] {
			let tokens = cred.components(separatedBy: ":")
			
			if tokens.count == 2 {
				let _ = verifyCred(u: tokens[0], p: tokens[1], save:false)
			}
		}
	}
	
	public func verifyCred(u: String, p: String, save: Bool = true) -> Bool{
		Task {
			print("verify user: \(u)")
			let okay = await discuz.login(name:u, pass:p)
			if okay {
				user = u
				pass = p
				
				if save {
					let cred = "\(u):\(p)"
					keychain[KeychainCredKey] = cred
					
#if DEBUG
					UserDefaults.standard.set(cred.data(using:.utf8), forKey: KeychainCredKey)
#endif
				}
				
				verified = true
			} else {
				clearCred()
				verified = false
			}
			print("send event login")
			sharedSubject.send(EventType.login)
		}
		
		return verified
	}
	
	func clearCred() {
		do {
			try keychain.remove(KeychainCredKey)
		}catch {
			print(error)
		}
	}
	
	func logout(){
		pass = nil
		user = nil
		verified = false
		clearCred()
		Task {
			await discuz.logout()
			print("send event logout")
			sharedSubject.send(EventType.logout)
		}
	}
	
}
