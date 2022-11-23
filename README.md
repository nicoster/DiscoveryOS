# DiscoveryOS
打造一个 macOS 上用起来很舒服的 Discovery 客户端
<img width="1338" alt="Screenshot 2022-11-23 at 16 49 28" src="https://user-images.githubusercontent.com/625174/203505051-372a74a1-8ee2-48f7-9379-1dd63010c048.png">


## How
受到了 [V2exOS](https://github.com/isaced/V2exOS) 的启发, 使用 SwiftUI 构建. 
其实也是第一次接触 SwiftUI, 这个 App 的开发也是自己的一个学习的过程. 所以很多问题的解法可能都比较简单粗暴. 我一般也都在代码里注明了`FIXME`

Discuz 没有 API, 靠 regexp 硬解 HTTP resposne. 具体可以查看 `DiscuzAPI.swift`. 
由于不依赖服务端 API, 所以有可能打造一个通用的 Discuz 客户端. 目前还是先做好一个吧.

## Where we are
- [x] 登陆
- [x] 回帖
- [x] 收藏
- [ ] 发帖
- [ ] 文件(图片)上传
- [ ] App 图标

## Credits
- [V2exOS](https://github.com/isaced/V2exOS) - 主要的灵感来源
- [Kingfisher](https://github.com/onevcat/Kingfisher) - 网络图片加载和缓存
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain 便捷访问
- [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) - SwiftUI Markdown 渲染
- [RedditOS](https://github.com/Dimillian/RedditOS) - 一个 SwiftUI 写的 Reddit macOS 客户端
