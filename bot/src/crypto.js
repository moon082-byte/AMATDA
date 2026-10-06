// 무작위 값·해시 (Workers와 Node 모두 Web Crypto를 쓴다)

/** URL에 써도 안전한 base64 */
export function base64url(bytes) {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** 추측할 수 없는 무작위 문자열 ([bytes]바이트 → 약 1.33배 길이) */
export function randomToken(bytes = 32) {
  return base64url(crypto.getRandomValues(new Uint8Array(bytes)));
}

export async function sha256Hex(text) {
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  return [...hash].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** PKCE: verifier → S256 challenge */
export async function pkceChallenge(verifier) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64url(new Uint8Array(hash));
}
