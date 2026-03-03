export default {
  async fetch(request) {
    const url = new URL(request.url);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=https://m1sk9.dev/posts/">
  <title>Redirecting...</title>
  <link rel="me" href="https://mstdn.maud.io/@m1sk9">
</head>
<body>
  <p>Redirecting to <a href="https://m1sk9.dev/posts/">m1sk9.dev/posts/</a>...</p>
</body>
</html>`;

    return new Response(html, {
      headers: {
        "content-type": "text/html;charset=UTF-8",
        "link": '<https://mstdn.maud.io/@m1sk9>; rel="me"',
      },
    });
  },
};
