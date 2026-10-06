// HTTP 응답 도우미

/** 상태 코드와 함께 던지는 오류 (index.js가 JSON 응답으로 바꾼다) */
export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function readJson(request) {
  try {
    return await request.json();
  } catch {
    throw new HttpError(400, 'JSON 형식이 아니에요');
  }
}

/** 입력 검사 함수가 던진 오류를 400 응답으로 바꾼다 */
export function validate(fn) {
  try {
    return fn();
  } catch (e) {
    throw e instanceof HttpError ? e : new HttpError(400, e.message);
  }
}

export function json(body, status, request, env) {
  return cors(new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  }), request, env);
}

export function text(body, status = 200) {
  return new Response(body, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
}

export function redirect(location) {
  return new Response(null, { status: 302, headers: { Location: location, 'Cache-Control': 'no-store' } });
}

/** 앱 주소(GitHub Pages)와 로컬 개발 주소에서만 호출할 수 있게 한다 */
export function cors(response, request, env) {
  const origin = request.headers.get('Origin') ?? '';
  const allowed = (env.ALLOWED_ORIGINS ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  if (allowed.includes(origin) || /^http:\/\/localhost(:\d+)?$/.test(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.headers.set('Access-Control-Max-Age', '86400');
    response.headers.set('Vary', 'Origin');
  }
  return response;
}
