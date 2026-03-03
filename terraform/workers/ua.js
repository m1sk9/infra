export default {
  async fetch(request) {
    const userAgent = request.headers.get("user-agent") || "";
    return new Response(userAgent + "\n", {
      headers: { "content-type": "text/plain;charset=UTF-8" },
    });
  },
};
