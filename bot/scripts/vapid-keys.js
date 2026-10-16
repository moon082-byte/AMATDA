// 푸시(Web Push)용 VAPID 키 한 쌍을 만든다: npm run vapid:keys
// 출력된 값을 `npx wrangler secret put <이름>`으로 등록한다 (비밀키는 다른 사람에게 보여 주지 마세요).
const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const publicRaw = new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey));
const { d } = await crypto.subtle.exportKey('jwk', pair.privateKey);
const b64 = (bytes) => Buffer.from(bytes).toString('base64url');
console.log(`VAPID_PUBLIC_KEY=${b64(publicRaw)}`);
console.log(`VAPID_PRIVATE_KEY=${d}`);
