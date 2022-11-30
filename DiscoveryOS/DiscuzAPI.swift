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

public struct Reply : Identifiable, Equatable {
	public static func == (lhs: Reply, rhs: Reply) -> Bool {
		lhs.id == rhs.id
	}
	
	internal init(id: String, author: User, at: String, seq: Int, len: Int = 1, body: String, markdown: String) {
		self.id = id
		self.author = author
		self.at = at
		self.seq = seq
		self.len = len
		self.body = body
		self.markdown = markdown
	}
	
	static func placeholder(seq : Int, len : Int) -> Reply {
		print("placeholder seq:\(seq) len:\(len)")
		assert(len > 0 && seq > 0)
		return Reply(id: "placeholder@\(seq)",
				  author: User(id: "", name: "", avatar: ""),
				  at: "",
				  seq: seq,
				  len: len,
				  body: "",
				  markdown: ""
		)
	}
	
	static let spinner = Reply(id: "spinner",
							   author: User(id: "", name: "", avatar: ""),
					  at: "",
					  seq: Int.max,
					  len: 0,
					  body: "",
					  markdown: ""
			)
	
	var isSpinner : Bool { id == "spinner" }
	
	var isPlaceholder : Bool { len > 1 }
	var pageSlots: String {
		let pageSize = DiscuzAPI.shared.pageSize
		let res = "折叠了 \(len) 个回帖 \(DiscuzAPI.shared.LineSeparator)" +
		Array((seq / pageSize + 1)..<((seq + len + pageSize) / pageSize)).map {"[\($0)](page:\($0))"}.joined(separator: " | ")
		print("page slots:\(res)")
		return res
	}
	
	public let id: String
	public let author : User
	public let at: String
	public let seq: Int
	public let len: Int		// when len isn't 1, this entry serves as a placeholder for multiple replies.
	public let body: String
	public let markdown: String
}

public struct Post : Identifiable {
	public let id: String
	public let title: String
	public let uid: String?
	public let author: String?
	public let at: String?
	public let replies: Int
	public let views: Int?
	public let lastReplyBy: String?
	public let lastReplyAt: String?
	
	static let separator = Post(id: "separator", title: "", uid: nil, author: nil, at: nil, replies: 0, views: nil, lastReplyBy: nil, lastReplyAt: nil)
	
	public var isSeparator : Bool {
		id == "separator"
	}
	
	var link : String {
		DiscuzAPI.shared.host + "viewthread.php?tid=\(id)"
	}
}

public struct Channel : Identifiable {
	public let id: String
	public let title : String
	public let description: String
	public let newPosts : Int?
}

extension String.Encoding {
	static let gb_18030_2000 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}

extension String {
	var htmlDecoded: String {
		let decoded = try? NSAttributedString(data: Data(utf8), options: [
			.documentType: NSAttributedString.DocumentType.html,
			.characterEncoding: String.Encoding.utf8.rawValue
		], documentAttributes: nil).string
		
		return decoded ?? self
	}
	
	var htmlEntities : String {
		String(flatMap {
			if let value = $0.unicodeScalars.first?.value,
			   (value > 127 && value < 0x3000) || value > 0x9fff {
				return "&#\(value);"
			} else {
				return String($0)
			}
		})
	}
	
	// see https://stackoverflow.com/questions/41477013/swift-removingpercentencoding-not-work-with-a-gb2312-string
	func urlencode(using encoding: String.Encoding = .gb_18030_2000) -> String? {
		var res = ""
		let src = self.replacingOccurrences(of: " ", with: "+")
		let allowedSet = NSMutableCharacterSet()
		allowedSet.formUnion(with:CharacterSet.urlQueryAllowed)
		allowedSet.removeCharacters(in: "&")
		let allowed = allowedSet as CharacterSet
		if let data = src.data(using: encoding) {
			res = data.reduce(into:res) {
				let scalar = UnicodeScalar($1)
				if $1 <= 127, allowed.contains(scalar) {
					$0 += String(Character(scalar))
				} else {
					$0 += String(format:"%%%02X", $1)
				}
			}
		}
		
		return res.isEmpty ? self : res
	}
	
	func replace(pattern : String, with template: String, options : NSRegularExpression.Options = .dotMatchesLineSeparators) -> String {
		let re = try! NSRegularExpression(pattern: pattern, options: options)
		return re.stringByReplacingMatches(in: self, options: [], range: NSRange(0..<self.utf16.count), withTemplate: template)
	}
	
	func captureGroups(regex: String, options: NSRegularExpression.Options = .dotMatchesLineSeparators, skipFirst: Bool = false) -> [String] {
		
		var results : [String] = []
		
		if let matches = try? NSRegularExpression(pattern: regex, options: .dotMatchesLineSeparators).matches(in: self, range: NSMakeRange(0, count)) {
			
			if matches.count > 1 {
				for match in matches {
					if let sub = Range(match.range(at: 0), in: self) {
						results.append(String(self[sub]))
					}
				}
				
				return results
			}
			
			guard let match = matches.first else {
				return results
			}
			
			let start = skipFirst ? 1 : 0
			for i in start..<match.numberOfRanges {
				if let sub = Range(match.range(at: i), in: self) {
					results.append(String(self[sub]))
				}
			}
		}
		
		return results
	}
	
	var markdown : String {
		var result : String = self
		let LineSeparator = "\u{2028}"

		// relative paths are handled by MarkdownUI (using baseURL)
		
		result = [
			("<a href=\"javascript:;\"><img onclick=\"zoom\\(this, '([^']+)'.*?</a>", "![]($1)"),
			("<a\\s+href=\"([^\"]+)\".*?>(.*?)</a>", "[$2]($1)"),
			("<img\\s+[^<>]*?src=\"([^\"]+images/smilies[^\"]+)\"", "![$2]($1)<img"),
			// 2 passes to handle 1 image with both `src` and `file` attributes
			("<img\\s+[^<>]*?(?:file|src)=\"([^\"]+)\"", "\n<br/>![$2]($1)\n<img"),
			("<img\\s+[^<>]*?(?:file|src)=\"([^\"]+)\"", "\n<br/>![$2]($1)\n<img"),
			("<blockquote>(.*>)([^>]+发表于.*?)</blockquote>", "$2```\(LineSeparator)$1```")
		].reduce(result) {
			$0.replace(pattern: $1.0, with: $1.1)
		}
		
//		if debug_markdown {
//			print("result:\(result)")
//		}
		
		if let attributed = try? NSAttributedString(data: result.data(using: .unicode)!, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
			result = attributed.string.replace(pattern: "\\[\\s*\n", with: "[")
				.replacingOccurrences(of: "[\\s*\n", with: "")
				.replace(pattern:"\n{3,}", with: "\n")
				.replacingOccurrences(of: "\n", with: LineSeparator)
		}
		
		return result
	}
}

var sharedFormHash : String? = nil

// a singleton has to be a class (instead of struct)
// see https://stackoverflow.com/a/36788519/590307
public class DiscuzAPI {
	
	static let shared = DiscuzAPI()
	
	let debug_loadreplies = false
//	let debug_markdown = false
	let debug_misc = false
	let debug_cookies = false
	let debug_traffic = false
	let debug_encoding = false
	
	let host = "https://www.4d4y.com/forum/"
	let loginRequired = "<select name=\"loginfield\" id=\"loginfield\">"
	var pageSize = 50
	var user : String? = nil
	var pass : String? = nil
	
	let session : URLSession
	
	var authenticated = false
	
	init(session: URLSession = .shared, user : String? = nil, pass : String? = nil) {
		self.session = session
		self.user = user
		self.pass = pass
	}
	
	let LineSeparator = "\u{2028}"
	
	func dorequest(method: String = "GET", url: String, args: [(String, Any)]? = nil,
				  moreheaders: [String: String]? = nil, retry : Bool = true) async throws -> (text: String?, resp: URLResponse?) {
		let urlComponents = NSURLComponents(string: url)!
		
		if method != "POST" && args != nil {
			urlComponents.queryItems =
			args?.map({ NSURLQueryItem(name: $0, value: "\($1)") }) as [URLQueryItem]?
		}
		
		guard let requestUrl = urlComponents.url else {
			return (nil, nil)
		}
		
		var request = URLRequest(url: requestUrl)
		request.httpMethod = method
		
		var headers = [
			"Content-Type": "application/x-www-form-urlencoded",
			"Accept-Encoding": "gzip, deflate, br",
			"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Connection": "keep-alive",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15",
		]
		if let moreheaders {
			headers = headers.merging(moreheaders){$1}
		}
		
		headers.forEach { field, value in request.addValue(value, forHTTPHeaderField: field) }
		
		if method == "POST" && args != nil{
			//    request.httpBody = try? JSONSerialization.data(withJSONObject: args as Any)
			let body = args?.map { "\($0)=\($1)" }.joined(separator: "&")
			if debug_traffic {
				print("httpbody:\(body!)")
			}
			request.httpBody = body?.data(using: .utf8)
		}
		
		let (data, resp) = try await session.data(for: request)
		let text = String(data: data, encoding: .gb_18030_2000)
		if debug_traffic {
			print("data: \(data)")
		}
		
		if let text {
			let formhash = text.captureGroups(regex: #"<a href="logging.php\?action=logout&amp;formhash=([^"]+)">退出</a>"#, skipFirst: true)
			if formhash.count > 0 {
				sharedFormHash = formhash[0]
			}
			if debug_misc {
				print("formhash: \(formhash)")
			}
		}
		
		if debug_cookies {
			let cookieStore = HTTPCookieStorage.shared
			for cookie in cookieStore.cookies ?? [] {
				print("cookie:\(cookie)")
			}
		}

		if retry, let text, text.contains(loginRequired), let user, let pass {
			print("re-login for \(url)")
			let _ = await dologin(name:user, pass:pass)
			return try await self.dorequest(method: method, url: url, args:args, retry:false)
		}
		return (text, resp)
		
	}
	
	func request(method: String = "GET", url: String, args: [(String, Any)]? = nil, retry : Bool = true) async throws -> String? {
		let (text, _) = try await dorequest(method: method, url: url, args: args, retry: retry)
		if let text {
			return text.replace(pattern: "\r\n", with: "\n")
		} else {
			return text
		}
	}
	
	public func login(name : String, pass : String) async -> Bool {
		let formhash = await dologin(name: name, pass: pass)
		if formhash != nil {
			self.user = name
			self.pass = pass
			
			self.authenticated = true
			
			await loadConfig()
			return true
		}
		
		self.authenticated = false
		return false
	}
	
	private func loadConfig() async {
		let html = try? await request(method: "GET", url: host + "memcp.php?action=profile&typeid=5")
		if let html {
			let psize = html.captureGroups(regex: #"name="pppnew" value="(\d+)" checked="checked""#, skipFirst: true)
			if psize.count > 0,
			   let pageSize = Int(psize[0]),
			   pageSize > 0 {
				self.pageSize = pageSize
			}
		}
	}
	
	private func dologin(name : String, pass : String) async -> String? {
		print("login \(name) ")
		let html = try? await request(method: "POST", url: host + "logging.php?action=login&loginsubmit=yes", args:[
			("username", name),
			("password", pass),
			("loginsubmit", "true")
		], retry: false)
		
		if let html {
			let formhash = html.captureGroups(regex: #"<a href="logging.php\?action=logout&amp;formhash=([^"]+)">退出</a>"#, skipFirst: true)
			print("login \(name) \(formhash)")
			
			
			return formhash.count > 0 ? formhash[0] : nil
		} else {
			return nil
		}
	}
	
	public func logout() async {
		
		let text = try? await request(method: "GET", url: host + "logging.php?action=logout&formhash=\(sharedFormHash ?? "")", retry: false)
		print("logout: \(text ?? "")")
		
		self.authenticated = false
		
		let cookieStore = HTTPCookieStorage.shared
		for cookie in cookieStore.cookies ?? [] {
			if debug_cookies {
				print("cookie:\(cookie)")
			}
			cookieStore.deleteCookie(cookie)
		}
	}
	
	/// - Parameters:
	///   - tid: the thread id
	///   - page: which page to load
	///   - pid: the reply id, if this param is present, `page` is ignored
	///
	/// - Returns: an array of ``Reply``, might be empty
	public func loadReplies(tid: String, page: Int = 1, pid: String? = nil) async -> [Reply] {
		print("start load post \(tid) page \(page)")
		var replies : [Reply] = []
		
		let html = try? await request(url: pid != nil
									  ? host + "redirect.php?goto=findpost&ptid=\(tid)&pid=\(pid!)"
									  : host + "viewthread.php?tid=\(tid)&page=\(page)")
		if let html {
			
//			let rows = html.components(separatedBy: "onclick=\"showWindow('reply', this.href);")
			let rows = html.components(separatedBy: #"<td class="postcontent postbottom">"#)
//			let rows = html.ranges(of:"onclick=\"showWindow('reply', this.href);", options: .regularExpression).map { String(html[$0]) }
			
			if rows.isEmpty {
				print("html: \(html)")
			}
//			print("rows:\(rows.count)")
			
			for row in rows {
//				row = [
//					// remove signature
//					"<div class=\"signatures\".*",
//					// remove report
//					".*onclick=\"showWindow\\('report', this.href\\);.*"
//				].reduce(row) {
//					$0.replace(pattern:$1, with: "", options: [])
//				}
				
				let col = row.captureGroups(regex: #"<table id=\"pid(\d+)\".*?space.php\?uid=(\d+).*?>([^<]+)</a>.*href=\"space.php\?uid=.*?<img src=\"([^\"]+)\".*<em>(\d+)</em><sup>#</sup>.*<em id=.*?>发表于 ([^<]+)</em>.*(<div class=\"postmessage.*)$"#, skipFirst: true)
				
				if col.isEmpty {
					if debug_loadreplies {
						print("row:+++++++++++++++++++++++++++++++++++\(row.count) \n\(row)")
					}
				} else {
					let user = User(id: col[1], name: col[2], avatar: col[3])
					let body = col[6]
//						let file = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("row")
//						do {try row.write(to: file, atomically: true, encoding: .utf8)} catch {print("err", error)}

					let reply = Reply(id: col[0], author:user, at: col[5], seq: Int(col[4]) ?? -1, body: body, markdown: body.markdown)
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
			let rows = html.captureGroups(regex: "<tr>.*?</tr>")
			for row in rows {
				let col = row.captureGroups(regex: "<span[^>]*><a href=\"viewthread.php\\?tid=(\\d+)[^>]*>([^<]+).*href=\"space.php\\?uid=(\\d+)\">([^<]+)</a>.*<em>(\\d{4}-\\d{1,2}-\\d{1,2})</em>.*<td class=\"nums\"><strong>(\\d+)</strong>/<em>(\\d+)</em></td>.*space.php\\?username=[^\"]+\">([^<]+)<.*lastpost\">([^<]+)<", skipFirst: true)
				if col.count > 0 {
					let post = Post(id:col[0], title: col[1].htmlDecoded, uid:col[2], author:col[3].removingPercentEncoding ?? col[3], at: col[4], replies: Int(col[5]) ?? 0, views: Int(col[6]) ?? 0, lastReplyBy: col[7].removingPercentEncoding ?? col[7], lastReplyAt: col[8])
					posts.append(post)
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
			let rows = html.captureGroups(regex: "<tr>.*?</tr>")
			//			print(rows[2])
			for row in rows {
				let col = row.captureGroups(regex: "forumdisplay.php\\?fid=(\\d+).*?>([^<]+)</a>.*?<p>((?:[^<]+)?)<", skipFirst: true)
				if col.count > 0 {
					let field = row.captureGroups(regex: "今日: <strong>(\\d+)", skipFirst: true)
					let newPosts = field.count == 1 ? Int(field[0]) ?? 0 : 0
					let channel = Channel(id: col[0], title: col[1], description: col[2], newPosts: newPosts)
					channels.append(channel)
				} else {
					if debug_loadreplies {
						print("channel: +++++++++++++++++++++++++++++\n\(row)")
					}
				}
			}
		}
		
		return channels
	}
	
	public func loadUser(name: String) async -> User? {
		if debug_traffic {
			print("start load user \(name)")
		}
		var user : User?
		
		if let urlencoded = name.urlencode(){

			let html = try? await request(url: host + "space.php?username=\(urlencoded)")
			if let html {
				// print(html)
				let col = html.captureGroups(regex: "\\(UID: (\\d+)\\).*<div class=\"avatar\"><img src=\"([^\"]+)", skipFirst: true)
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
			let rows = html.captureGroups(regex: "<tr>.*?</tr>")
			for row in rows {
				// print(row)
				let col = row.captureGroups(regex: "<a href=\"viewthread.php\\?tid=(\\d+).*?>([^<]+)</a>.*?<a href=\"forumdisplay.php.*?>([^<]+)</a>.*?<td class=\"nums\">(\\d+)</td>.*?space.php\\?username[^>]+>([^<]+)</a>.*?lastpost\">([^<]+)</a>", skipFirst: true)
				if col.count > 0 {
					// print(col)
					let post = Post(id:col[0], title: col[1].htmlDecoded, uid:nil, author:nil, at: nil, replies: Int(col[3]) ?? 0, views: nil, lastReplyBy: col[4].removingPercentEncoding ?? col[4], lastReplyAt: col[5])
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
			print("bookmark \(id): \(text ?? "")")
		}
		
		return okay
	}
	
	func quoted(channel: Channel, postInfo: Post, quote: Reply) -> String {
"""
[quote] \(quote.markdown)
[size=2][color=#999999]\(quote.author.name) 发表于 \(quote.at)[/color] [url=\(host)redirect.php?goto=findpost&pid=\(quote.id)&ptid=\(channel.id)][img]\(host)images/common/back.gif[/img][/url][/size][/quote]
"""
	}
	
	public func postReply(fid: String, tid: String, content: String) async -> Bool {
		print("reply fid:\(fid) tid:\(tid) msg:\(content)")
		

		if let cookie = HTTPCookie(properties: [
			.domain: "www.4d4y.com",
			.path: "/",
			.name: "discuz_fastpostrefresh",
			.value: "0",
			.secure: "FALSE",
			.discard: "TRUE"
		]) {
			HTTPCookieStorage.shared.setCookie(cookie)
//			print("Cookie inserted: \(cookie)")
		}
		
		let normalized = content.replacingOccurrences(of: "\n", with: "\r\n").htmlEntities.urlencode()!
		if debug_encoding {
			print("normalized:\(normalized)")
		}
		let result = try? await dorequest(method: "POST",
										 url: host + "post.php?action=reply&fid=\(fid)&tid=\(tid)&extra=page%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1",
										 args: [
											("formhash", sharedFormHash!),
											("subject", ""),
											("usesig", "0"),
											("message", normalized),
										 ]
		)
		
		handleResult(html: result?.text)
		return true
	}
	
	private func handleResult(html: String?) {
		if let html {
			
			if html.contains("非常感谢，您的回复已经发布，现在将转入主题页") {
				return
			}
			
			// <div class="alert_info"> <p>您的请求来路不正确，无法提交。</p> </div>
			let foo = html.captureGroups(regex: #"<div class="postbox">(.*?)</div>"#)
			if !foo.isEmpty {
				print("result: \(foo[0]) ")
			} else {
				print("result: \(html)")
			}
		}
	}
}
