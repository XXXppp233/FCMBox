# 后端代码示例

### Cloudflare

[Cloudflare Workers Code Sample](cloudflare.js)

部署在 Cloudflare Workers 上，绑定一个 KV 命名空间，KV 中应至少包含一个 service-account 对来存储 service-account.json
一个 D1 数据库，包含一张名为 main 的表，至少包含 timestamp int, data, overview, service, image 五个列，一张名为 tokens 的表，包含 token, device 两个列。
```
CREATE TABLE main (
    timestamp INTEGER PRIMARY KEY NOT NULL,
    data TEXT,
    overview TEXT,
    service TEXT,
    image TEXT
) WITHOUT ROWID;

CREATE TABLE tokens (
    token TEXT PRIMARY KEY,
    device TEXT NOT NULL
) WITHOUT ROWID;
```