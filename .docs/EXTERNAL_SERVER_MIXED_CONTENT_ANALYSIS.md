# External Server Mixed-Content Analysis

## Summary

The deployed app is very likely being blocked by the browser because the app page is loaded over HTTPS, but the external
server API request is being made over plain HTTP:

- App origin: `https://...`
- API request: `http://eco.greenleafserver.com:3021/api/v1/plugins/EcoPriceCalculator/allItems`

That combination is classified as **mixed content**. Modern browsers block active mixed content such as `fetch`,
`XMLHttpRequest`, and Angular `HttpClient` calls, which matches the `blocked:mixed-content` status you are seeing.

## Why it works locally

Locally, the app is usually served from `http://localhost:4200` or `http://127.0.0.1:4200`, so the request is:

- Local app origin: `http://...`
- API request: `http://...`

That is **not** mixed content, so the browser allows it.

## Why typing the URL into the browser works

Pasting the URL directly into the browser address bar is a **top-level navigation**, not a subresource request from an
HTTPS page.

In other words:

- `https://your-app/...` -> JavaScript fetches `http://...` = blocked mixed content
- Browser navigates directly to `http://...` = allowed navigation to that URL

So the fact that the URL responds in the address bar does **not** prove it can be fetched by JavaScript from inside the
deployed HTTPS app.

## How the app currently builds the request

The frontend makes the server call directly from the browser via Angular `HttpClient`. In
`EcoCraftingTool/src/app/service/price-calculator-server.service.ts`, the protocol is selected from the
`useInsecureHttp` flag:

```ts
const protocol = useInsecureHttp ? 'http://' : 'https://';
const url = protocol + host + this.baseUrlPath + this.itemsPath;
return this.http.get<ServerItemsResponse>(url);
```

That means if this server configuration is using `useInsecureHttp = true`, the deployed browser app will attempt a
direct HTTP request and the browser will block it before the connection can succeed.

## Root cause

The root cause is **browser security policy**, not necessarily a bad response from the Greenleaf server.

The request is being blocked because:

1. the deployed app runs over HTTPS
2. the external Eco server endpoint is HTTP-only
3. the request is made directly from browser code

## Likely fix options

### Best option: provide HTTPS on the external API

Expose the Eco Price Calculator plugin endpoint over HTTPS, preferably on a standard public HTTPS endpoint with a valid
certificate.

Examples:

- `https://eco.greenleafserver.com/api/v1/plugins/EcoPriceCalculator/allItems`
- `https://eco.greenleafserver.com:3021/api/v1/plugins/EcoPriceCalculator/allItems` (only if TLS is correctly configured
  on that port)

### Alternative: place an HTTPS reverse proxy in front of the Eco server

Use Nginx, Caddy, Apache, Cloudflare Tunnel, or another reverse proxy so the browser talks to HTTPS while the proxy
forwards to the internal HTTP service.

### Alternative: proxy through your own backend

Instead of calling the Eco server directly from the browser, route the request through your own HTTPS backend or server
function. The browser would call your backend over HTTPS, and your backend could then call the HTTP Eco server.

## Additional note: CORS may be the next issue

If you fix the mixed-content problem and keep the request browser-direct, the next possible failure is **CORS**.

That means the external server may also need to allow requests from your deployed app origin, for example:

- `https://eco-calc.com`

But right now the reported `blocked:mixed-content` status indicates the mixed-content restriction happens first.

## Practical conclusion

The deployed app fails because an HTTPS page is trying to fetch an HTTP API endpoint, and the browser blocks that
request as mixed content.

The URL works when opened directly because that is a browser navigation, not an embedded API call from the deployed app.
