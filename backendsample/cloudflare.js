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
        const saJson = await env.KV.get('service-account')
        const FCMToken = await env.KV.get('token')
        // FCMSender(serviceAccount, FCMToken, data)
        if (saJson && FCMToken) {
            const serviceAccount = JSON.parse(saJson);
            ctx.waitUntil(FCMSender(serviceAccount, FCMToken, overview, data, service, image || ALTER_IMG ));
          }


        return new Response("success")
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
      if (body.token != undefined){
        await env.KV.put('token', body.token)
        return new Response("success")
      }else {
        return new Response("Invalid Method")
      }
      
    }
  }
};

async function FCMSender(sa, token, overview, data, service, image) {
  try {
    const accessToken = await getAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const fcmBody = {
      message: {
        token: token,
        notification: {
          title: service,
          body: overview,
          image: image
        },
        data: {
          timestamp: String(Date.now()),
          main: typeof data === 'object' ? JSON.stringify(data) : String(data)
        }
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

    return await res.json();
  } catch (err) {
    console.error("FCM Send Error:", err);
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