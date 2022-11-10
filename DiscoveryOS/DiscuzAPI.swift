//
//  DiscuzAPI.swift
//  DiscuzAPI
//
//  Created by Nick Xiao on 2022/10/31.
//

import Foundation

public struct User : Identifiable {
	public let id: String
	public let name: String
	public let avatar: String
}

public struct Reply : Identifiable {
	public let id: String
	public let author : User
	public let at: String
	public let index: String
	public let body: String
	public let markdown: String
}

public struct Post : Identifiable {
	public let id: String
	public let title: String
	public let uid: String?
	public let author: String?
	public let created: String?
	public let replies: Int
	public let views: Int?
	public let lastReplyBy: String?
	public let lastReplyAt: String?
}

public struct Channel : Identifiable {
	public let id: String
	public let title : String
	public let description: String
	public let newPosts : Int?
}

extension String {
	var htmlDecoded: String {
		let decoded = try? NSAttributedString(data: Data(utf8), options: [
			.documentType: NSAttributedString.DocumentType.html,
			.characterEncoding: String.Encoding.utf8.rawValue
		], documentAttributes: nil).string
		
		return decoded ?? self
	}
	
	func urlencoded() -> String? {
		let unreserved = "-._~/?"
		let allowed = NSMutableCharacterSet.alphanumeric()
		allowed.addCharacters(in: unreserved)
		return addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
	}
	
	func replace(pattern : String, with template: String, options : NSRegularExpression.Options = .dotMatchesLineSeparators) -> String {
		let re = try! NSRegularExpression(pattern: pattern, options: options)
		return re.stringByReplacingMatches(in: self, options: [], range: NSRange(0..<self.utf16.count), withTemplate: template)
	}
}

public struct DiscuzAPI {
	
	let host = "https://www.4d4y.com/forum/"
	let loginRequired = "<select name=\"loginfield\" id=\"loginfield\">"
	let pageSize = 15
	var user : String? = nil
	var pass : String? = nil
	
	let session : URLSession
	
	init(session: URLSession = .shared, user : String? = nil, pass : String? = nil) {
		self.session = session
		self.user = user
		self.pass = pass
	}
	
	public func makeMarkdown(src: String) -> String {
		var result : String = src
		
		// relative paths are handled by MarkdownUI (using baseURL)
		
		result = [
			("<a\\s+href=\"([^\"]+)\".*?>(.*?)</a>", "[$2]($1)"),
			// 2 passes to handle 1 image has both `src` and `file` attributes
			("<img\\s+[^<>]*?(?:file|src)=\"([^\"]+)\"", "\n<br/>![$2]($1)\n<img"),
			("<img\\s+[^<>]*?(?:file|src)=\"([^\"]+)\"", "\n<br/>![$2]($1)\n<img"),
			("<blockquote>", "<br/>```<br/><br/>"),
			("([^>]+发表于.*?)</blockquote>", "```<br/>\n$1")
		].reduce(result) {
			$0.replace(pattern: $1.0, with: $1.1)
		}
		
		if let attributed = try? NSAttributedString(data: result.data(using: .unicode)!, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
			result = attributed.string.replace(pattern: "\\[\\s*\n", with: "[")
				.replacingOccurrences(of: "[\\s*\n", with: "")
			
			if let range = result.range(of: "```", options: NSString.CompareOptions.backwards) {
				//FIXME: there must be a better way to do this
				result = result.replacingOccurrences(of: "\n", with: "\n\n", range: range.lowerBound..<String.Index(encodedOffset:result.utf16.count))
			} else {
				result = result.replacingOccurrences(of: "\n", with: "\n\n")
			}
		}
		
		return result
	}
	
	func capturedGroups(regex: String, text: String, options: NSRegularExpression.Options = .dotMatchesLineSeparators, skipFirst: Bool = false) -> [String] {
		
		var results : [String] = []
		
		if let matches = try? NSRegularExpression(pattern: regex, options: .dotMatchesLineSeparators).matches(in: text, range: NSMakeRange(0, text.count)) {
			//			print("count: \(matches.count)")
			
			if matches.count > 1 {
				for match in matches {
					if let sub = Range(match.range(at: 0), in: text) {
						results.append(String(text[sub]))
					}
				}
				
				return results
			}
			
			guard let match = matches.first else {
				return results
			}
			
			let start = skipFirst ? 1 : 0
			for i in start..<match.numberOfRanges {
				//				print("i: \(i) \(match.range(at: i))")
				if let sub = Range(match.range(at: i), in: text) {
					results.append(String(text[sub]))
				}
			}
		}
		
		return results
	}
	
	
	public let GB_18030_2000 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
	
	
	func request(method: String = "GET", url: String, args: [String: Any]? = nil, retry : Bool = true) async throws -> String? {
		let urlComponents = NSURLComponents(string: url)!
		
		if method != "POST" && args != nil {
			urlComponents.queryItems =
			args?.map({ (k, v) in
				return NSURLQueryItem(name: k, value: "\(v)")
			}) as [URLQueryItem]?
		}
		
		guard let requestUrl = urlComponents.url else {
			return nil
		}
		
		var request = URLRequest(url: requestUrl)
		request.httpMethod = method
		
		let headers = [
			"Content-Type": "application/x-www-form-urlencoded",
			"Accept-Encoding": "gzip, deflate, br",
			"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Connection": "keep-alive",
		]
		headers.forEach { field, value in request.addValue(value, forHTTPHeaderField: field) }
		
		if method == "POST" && args != nil{
			//    request.httpBody = try? JSONSerialization.data(withJSONObject: args as Any)
			request.httpBody = args?.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
		}
		
		let (data, _) = try await session.data(for: request)
		let text = String(data: data, encoding: GB_18030_2000)
		print("data: \(data)")
		
		if retry, let text, text.contains(loginRequired), let user, let pass {
			print("_/\\_/\\_/\\_/\\_/\\_/\\_/\\_/\\_/\\_/\\_/\\_ re-login for \(url)")
			let _ = await dologin(name:user, pass:pass)
			return try await self.request(method: method, url: url, args:args, retry:false)
		}
		return text
		
	}
	
	public mutating func login(name : String, pass : String) async -> Bool {
		let okay = await dologin(name: name, pass: pass)
		if okay {
			self.user = name
			self.pass = pass
		}
		
		return okay
	}
	
	private func dologin(name : String, pass : String) async -> Bool {
		print("login \(name) ")
		let text = try? await request(method: "POST", url: host + "logging.php?action=login&loginsubmit=yes", args:[
			"username": name,
			"password": pass,
			"loginsubmit": "true"
		], retry: false)
		
		//		print("login: \(String(describing: text))")
		let okay = text?.contains("欢迎您回来") ?? false
		print("login \(name) \(okay)")
		return okay
	}
	
	public func logout() async {
		
		let text = try? await request(method: "GET", url: host + "logging.php?action=logout", retry: false)
		print("logout: \(text ?? "")")
		
		let cookieStore = HTTPCookieStorage.shared
		for cookie in cookieStore.cookies ?? [] {
//			print("cookie:\(cookie)")
			cookieStore.deleteCookie(cookie)
		}
	}
	
	public func loadReplies(tid: String, page: Int = 1) async -> [Reply] {
		print("start load post \(tid) page \(page)")
		var replies : [Reply] = []
		
		let html = try? await request(url: host + "viewthread.php?tid=\(tid)&page=\(page)")
		if let html {
			
			let rows = html.components(separatedBy: "onclick=\"showWindow('report', this.href);")
			
			if rows.isEmpty {
				print("html: \(html)")
			}
			
			for var row in rows {
				// remove signature
				row = row.replace(pattern: "<div class=\"signatures\".*", with: "", options: [])
				let col = capturedGroups(regex: "<table id=\"pid(\\d+)\".*?space.php\\?uid=(\\d+).*?>([^<]+)</a>.*href=\"space.php\\?uid=.*?<img src=\"([^\"]+)\".*<em>(\\d+)</em><sup>#</sup>.*<em id=.*?>发表于 ([^<]+)</em>.*(<table cell.*)", text: row, skipFirst: true)
				
				if col.isEmpty {
					print("row:+++++++++++++++++++++++++++++++++++\(row.count) \n\(row)")
				} else {
					let user = User(id: col[1], name: col[2], avatar: col[3])
					let body = col[6]
					let markdown = makeMarkdown(src:body)
					let reply = Reply(id: col[0], author:user, at: col[5], index: col[4], body: body, markdown: markdown)
					print("reply:\(reply.author)")
					replies.append(reply)
				}
			}
		}
		
		return replies
	}
	
	public func loadPosts(fid : String, page : Int = 1) async -> [Post] {
		print("start load channel \(fid)")
		var posts : [Post] = []
		let html = try? await request(url: host + "forumdisplay.php?fid=\(fid)&page=\(page)")
		if let html {
			let rows = capturedGroups(regex: "<tr>.*?</tr>", text: html)
			for row in rows {
				let col = capturedGroups(regex: "<span[^>]*><a href=\"viewthread.php\\?tid=(\\d+)[^>]*>([^<]+).*href=\"space.php\\?uid=(\\d+)\">([^<]+)</a>.*<em>(\\d{4}-\\d{1,2}-\\d{1,2})</em>.*<td class=\"nums\"><strong>(\\d+)</strong>/<em>(\\d+)</em></td>.*space.php\\?username=[^\"]+\">([^<]+)<.*lastpost\">([^<]+)<", text: row, skipFirst: true)
				if col.count > 0 {
					let post = Post(id:col[0], title: col[1].htmlDecoded, uid:col[2], author:col[3].removingPercentEncoding ?? col[3], created: col[4], replies: Int(col[5]) ?? 0, views: Int(col[6]) ?? 0, lastReplyBy: col[7].removingPercentEncoding ?? col[7], lastReplyAt: col[8])
					posts.append(post)
				} else {
					print("fields:", col)
				}
			}
		}
		
		return posts
	}
	
	public func loadChannels() async -> [Channel] {
		print("load channels")
		var channels : [Channel] = []
		let html = try? await request(url: host + "index.php")
		if let html {
			let rows = capturedGroups(regex: "<tr>.*?</tr>", text: html)
			//			print(rows[2])
			for row in rows {
				let col = capturedGroups(regex: "forumdisplay.php\\?fid=(\\d+).*?>([^<]+)</a>.*?<p>((?:[^<]+)?)<", text: row, skipFirst: true)
				if col.count > 0 {
					let field = capturedGroups(regex: "今日: <strong>(\\d+)", text: row, skipFirst: true)
					let newPosts = field.count == 1 ? Int(field[0]) ?? 0 : 0
					let channel = Channel(id: col[0], title: col[1], description: col[2], newPosts: newPosts)
					channels.append(channel)
				} else {
					print("channel: +++++++++++++++++++++++++++++\n\(row)")
				}
			}
		}
		
		return channels
	}
	
	public func loadUser(name: String) async -> User? {
		print("start load user \(name)")
		var user : User?
		
		if let urlencoded = name.urlencoded(){
			
			let html = try? await request(url: host + "space.php?username=\(urlencoded)")
			if let html {
				// print(html)
				let col = capturedGroups(regex: "\\(UID: (\\d+)\\).*<div class=\"avatar\"><img src=\"([^\"]+)", text: html, skipFirst: true)
				if col.count > 0 {
					user = User(id:col[0], name: name, avatar: col[1])
				}
			}
		}
		
		return user
	}
	
	/*
	 <tr>
	 <td><input class="checkbox" type="checkbox" name="delete[]" value="3101657"></td>
	 <th><a href="viewthread.php?tid=3101657&amp;from=favorites" target="_blank">开贴谈谈我是如何高效率的工作，高效率的 Get Things Done 和让团队高效率运转</a></th>
	 <td class="forum"><a href="forumdisplay.php?fid=2&amp;from=favorites" target="_blank">Discovery</a></td>
	 <td class="nums">409</td>
	 <td class="lastpost">
	 <cite><a href="space.php?username=ashbury&amp;from=favorites" target="_blank">ashbury</a></cite>
	 <em><a href="redirect.php?tid=3101657&amp;from=favorites&amp;goto=lastpost#lastpost">2022-11-5 08:24</a></em>
	 </td>
	 </tr>
	 */
	public func loadBookmarks(page: Int = 1) async -> [Post] {
		var bookmarks : [Post] = []
		let html = try? await request(url: host + "my.php?item=favorites&type=thread&page=\(page)")
		if let html {
			let rows = capturedGroups(regex: "<tr>.*?</tr>", text: html)
			for row in rows {
				// print(row)
				let col = capturedGroups(regex: "<a href=\"viewthread.php\\?tid=(\\d+).*?>([^<]+)</a>.*?<a href=\"forumdisplay.php.*?>([^<]+)</a>.*?<td class=\"nums\">(\\d+)</td>.*?space.php\\?username[^>]+>([^<]+)</a>.*?lastpost\">([^<]+)</a>", text: row, skipFirst: true)
				if col.count > 0 {
					// print(col)
					let post = Post(id:col[0], title: col[1].htmlDecoded, uid:nil, author:nil, created: nil, replies: Int(col[3]) ?? 0, views: nil, lastReplyBy: col[4].removingPercentEncoding ?? col[4], lastReplyAt: col[5])
					bookmarks.append(post)
				}
			}
		}
		
		return bookmarks
	}
	
	public func bookmarkPost(id: String) async -> Bool {
		let text = try? await request(url: host + "my.php?item=favorites&tid=\(id)&inajax=1&ajaxtarget=favorite_msg")
		
		let okay = text?.contains("此主题已成功添加到收藏夹中") ?? false
		if !okay {
			print("bookmark \(id): \(String(describing: text))")
		}
		
		return okay
	}
}
