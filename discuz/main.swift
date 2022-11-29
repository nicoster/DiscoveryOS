//
//  main.swift
//  discuz
//
//  Created by Nick Xiao on 2022/11/22.
//

import Foundation
import Kingfisher

var discuz = DiscuzAPI.shared
let user = "", pass = ""

func main() async {
	KingfisherManager.shared.downloader.sessionConfiguration = URLSessionConfiguration.default
	
	var page = 0
	var prev : [Reply] = []
	let okay = await discuz.login(name: user, pass: pass)
	if !okay {
		print("wrong username or password, abort.")
		return
	}
	
	while true {
		page += 1
		let replies = await discuz.loadReplies(tid: "202390", page: page)
		for item in replies {
			if prev.first(where:{$0.id == item.id}) != nil {
				print("\(item.seq)# already exists, stop loading")
				return
			}
			
			print(item.markdown)
		}
		
		prev = replies
		try? await Task.sleep(nanoseconds: 400000)
	}
}

await main()
