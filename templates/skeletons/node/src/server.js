import { createServer } from "node:http";
import { pathToFileURL } from "node:url";

export function handler(req, res) {
  if (req.url !== "/") {
    res.writeHead(404).end();
    return;
  }
  const body = "hola\n";
  res.writeHead(200, {
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT ?? 8080);
  createServer(handler).listen(port, "127.0.0.1");
}
