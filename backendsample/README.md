# 后端代码示例

## 完整的 FCM Box 介绍
[FCM Box Guide](https://docs.wepayto.win/application/fcmbox/)

## Cloudflare

[Cloudflare Workers Code Sample](cloudflare.js)

这个是当前我所用的服务端代码示例，使用了 Cloudflare D1 数据库和免费的 Workers 计算资源。所以我可以提供免费的服务。


对于要自己部署在 Cloudflare Workers 上的，绑定一个 KV 命名空间，KV 中应至少包含一个 service-account 对来存储 service-account.json
一个 D1 数据库，包含一张名为 main 的表，至少包含 timestamp int, data, overview, service, image 五个列，一张名为 tokens 的表，至少包含 token, device 两个列。



