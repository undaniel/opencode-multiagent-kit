import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import { handler } from "../src/server.js";

test("GET / responde 200 con hola", async () => {
  const server = createServer(handler).listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));

  try {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/`);
    assert.equal(res.status, 200);
    assert.match(await res.text(), /hola/);
  } finally {
    server.close();
  }
});
