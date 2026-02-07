const AUTH_HEADER = "YOUR_AUTH_HEADER"
const ALTER_IMG = `YOUR_ALTERNATE_IMAGE_URL`


export default {
  async fetch(request, env, ctx) {
    // You can view your logs in the Observability dashboard
    const auth = request.headers.get('Authorization')
    if (auth != AUTH_HEADER){
      return new Response("Auth Fail", {status: 403})
    }
    if (request.method == "GET"){
      const url = new URL(request.url)
      if (url.pathname == "/favicon.ico"){
        const cfico = `https://img.icons8.com/external-tal-revivo-filled-tal-revivo/96/external-cloudflare-provides-content-delivery-network-services-ddos-mitigation-logo-filled-tal-revivo.png`
        return Response.redirect(cfico, 302)
      }
      const html = `
      <!DOCTYPE html>
      <html>
        <head>
          <title>Cloudflare Workers</title>
          <meta charset="utf-8">
        </head>
        <body>
          <h1>Hellooooo Wooooorld</h1>
        </body>
      </html>
      `
      return new Response(html, {
        headers: {
          "Content-Type": "text/html;charset=UTF-8",
        },
      });
    }
    if (request.method == "POST"){
      const body = await request.json()
      
      if(body.action == "message"){
        const data = body.data || null
        const overview = body.overview || "Null Overview"
        const service = body.service || "Null Service"
        const image = body.image || null  //`https://img.icons8.com/clouds/100/fire-element.png`
        // write to D1 SQL
        await env.DB.prepare('INSERT INTO main (timestamp, data, service, overview, image) VALUES (?, ?, ?, ?, ?)').bind(
          Date.now(),
          typeof data === 'object' ? JSON.stringify(data) : data || null,
          service || null,
          overview,
          image
        ).run()
        
        // FCM Sender
        const saJson = await env.KV.get('service-account');
        if (saJson) {
          const serviceAccount = JSON.parse(saJson);
    
          // 1. 从 D1 获取所有 Token
          const { results: tokenRows } = await env.DB.prepare('SELECT device, token FROM tokens').all();

          if (tokenRows && tokenRows.length > 0) {
          // 2. 并发构造推送任务
          const tasks = tokenRows.map(async (row) => {
            const success = await FCMSender(
                serviceAccount, 
                row.token, 
                overview, 
                service, 
                image || ALTER_IMG
            );

            // 3. 如果发送失败，输出并清理
            if (!success) {
                console.log(`Fail to send to ${row.device}, rm token`);
                // 异步清理 D1 中的失效 Token，不阻塞其他任务
                ctx.waitUntil(
                    env.DB.prepare('DELETE FROM tokens WHERE device = ?').bind(row.device).run()
                    );
            }
        });
        // 4. 使用 waitUntil 确保所有并发请求在 Worker 关闭前完成
        ctx.waitUntil(Promise.allSettled(tasks));
      }
    }
    return new Response("success");
      }
      if(body.action == "get"){
        const quantity = body.quantity || 5  // default is the latest 5 logs
        const service = body.service || null
        if (service != null){
          const logs = await env.DB.prepare('SELECT * FROM main WHERE service = ? ORDER BY timestamp DESC LIMIT ?').bind(service, quantity).all()
          console.log("Get ",quantity, "logs about ", service)
          return new Response(JSON.stringify(logs.results))
        }
        else{
          const logs = await env.DB.prepare('SELECT * FROM main ORDER BY timestamp DESC LIMIT ?').bind(quantity).all()
          console.log("Get ",quantity, "logs")
          return new Response(JSON.stringify(logs.results))
        }

      }
      return new Response("hellooooo Wooooorld!")
    }
    if (request.method == "PUT"){
      const body = await request.json()
      if (body.token != undefined && body.device != undefined){
        await env.DB.prepare('INSERT INTO tokens (token, device) VALUES (?, ?)').bind(body.token, body.device).run()
        return new Response("success")
      }else {
        return new Response("Invalid Method")
      }
      
    }
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