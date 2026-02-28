const ALTER_IMG = `https://img.icons8.com/clouds/100/fire-element.png`


export default {
  async fetch(request, env, ctx) {
    const auth = request.headers.get('Authorization');
    const url = new URL(request.url);

    // --- GET 请求处理 (公开访问) ---
    if (request.method === "GET") {
      if (url.pathname === "/favicon.ico") {
        const cfico = `https://img.icons8.com/external-tal-revivo-filled-tal-revivo/96/external-cloudflare-provides-content-delivery-network-services-ddos-mitigation-logo-filled-tal-revivo.png`;
        return Response.redirect(cfico, 302);
      }
      const html = `<!DOCTYPE html><html><head><title>Cloudflare Workers</title><meta charset="utf-8"></head><body><h1>Service Active</h1></body></html>`;
      return new Response(html, { headers: { "Content-Type": "text/html;charset=UTF-8" } });
    }

    // --- 权限校验 (针对 POST 和 PUT) ---
    if (!auth) {
      return new Response("Missing Authorization", { status: 401 });
    }

    // --- POST 请求处理 ---
    if (request.method === "POST") {
      const body = await request.json();

      // Action: Message (写入日志并推送)
      if (body.action === "message") {
        const { data, overview = "Null Overview", service = "Null Service", image = null } = body;

        // 1. 写入 D1 (包含 authorization 列)
        await env.DB.prepare(
          'INSERT INTO main (timestamp, data, service, overview, image, authorization) VALUES (?, ?, ?, ?, ?, ?)'
        ).bind(
          Date.now(),
          typeof data === 'object' ? JSON.stringify(data) : data || null,
          service,
          overview,
          image,
          auth // 记录该条消息属于哪个用户
        ).run();

        // 2. FCM 推送逻辑
        const saJson = await env.KV.get('service-account');
        if (saJson) {
          const serviceAccount = JSON.parse(saJson);
          // 从 users 表获取该 auth 对应的所有 tokens
          const userRow = await env.DB.prepare('SELECT tokens, devices FROM users WHERE authorization = ?').bind(auth).first();

          if (userRow && userRow.tokens) {
            const tokenList = userRow.tokens.split(';').filter(t => t);
            const tasks = tokenList.map(async (token) => {
              return await FCMSender(serviceAccount, token, overview, service, image || ALTER_IMG);
            });
            // 这里暂不处理单个 token 失效的自动删除，因为字符串拼接逻辑较复杂，建议定期手动清理或在前端更新
            ctx.waitUntil(Promise.allSettled(tasks));
          }
        }
        return new Response("success");
      }

      // Action: Get (查询日志)
      if (body.action === "get") {
        const quantity = body.quantity || 5;
        const service = body.service || null;

        let query, params;
        if (service) {
          query = 'SELECT * FROM main WHERE authorization = ? AND service = ? ORDER BY timestamp DESC LIMIT ?';
          params = [auth, service, quantity];
        } else {
          query = 'SELECT * FROM main WHERE authorization = ? ORDER BY timestamp DESC LIMIT ?';
          params = [auth, quantity];
        }

        const logs = await env.DB.prepare(query).bind(...params).all();
        return new Response(JSON.stringify(logs.results), { headers: { "Content-Type": "application/json" } });
      }
    }

    // --- PUT 请求处理 (注册/更新 Token) ---
    if (request.method === "PUT") {
      const body = await request.json();
      const { token, device } = body;

      if (!token || !device) return new Response("Invalid Payload", { status: 400 });
      if (device.includes(';')) return new Response("Device name cannot contain ';'", { status: 400 });

      // 获取现有数据
      const user = await env.DB.prepare('SELECT tokens, devices FROM users WHERE authorization = ?').bind(auth).first();

      if (user) {
        let tokens = user.tokens ? user.tokens.split(';') : [];
        let devices = user.devices ? user.devices.split(';') : [];

        // 如果 token 不在列表中，则添加
        if (!tokens.includes(token)) {
          tokens.push(token);
          devices.push(device);
          await env.DB.prepare('UPDATE users SET tokens = ?, devices = ? WHERE authorization = ?')
            .bind(tokens.join(';'), devices.join(';'), auth)
            .run();
        }
        return new Response("updated");
      } else {
        // 如果用户不存在，可能需要先通过注册流程创建用户，或者直接在此创建（取决于你的业务逻辑）
        return new Response("User not found. Please register first.", { status: 404 });
      }
    }

    return new Response("Invalid Method", { status: 405 });
  }
};

async function FCMSender(sa, token, overview, service, image) {
  try {
    const accessToken = await getAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const fcmBody = {
      message: {
        token: token,
        notification: { title: service, body: overview, image: image },
      }
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(fcmBody)
    });

    const result = await res.json();

    if (res.ok) {
      return true; // 发送成功
    } else {
      // 重点：检查是否为 Token 失效
      // FCM v1 错误码 UNREGISTERED (404) 或 INVALID_ARGUMENT (400)
      if (res.status === 404 || (result.error && result.error.status === 'UNREGISTERED')) {
        return false; // 触发外层清理逻辑
      }
      console.error(`FCM API Error [${res.status}]:`, result.error?.message);
      return true; // 其他类型的错误（如 500）暂时不删除 Token，避免误删
    }
  } catch (err) {
    console.error("Network or Auth Error:", err);
    return true; // 网络波动导致失败，不建议删除 Token
  }
}

/**
 * 生成 Google OAuth2 Access Token (RS256)
 */
async function getAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };

  const base64UrlEncode = (str) => btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // 处理私钥
  const pemContents = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const importedKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    importedKey,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  
  const jwt = `${unsignedToken}.${encodedSignature}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });

  const tokenData = await response.json();
  return tokenData.access_token;
}