// lain.m1sk9.dev — Discord チャット AI「lain」の利用案内
// 静的な 1 ページ。実体は s1 の Hermes Agent コンテナ（ansible/roles/docker_compose_app/files/hermes/）。

const HTML = `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>lain</title>
<style>
  :root {
    --bg: #fbfbfc;
    --fg: #24242a;
    --muted: #6b6b76;
    --rule: #e2e2e8;
    --accent: #3b3b7a;
    --code-bg: #f0f0f3;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #16161a;
      --fg: #d8d8de;
      --muted: #8d8d99;
      --rule: #2c2c33;
      --accent: #a3a3d9;
      --code-bg: #202027;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 3rem 1.25rem 5rem;
    background: var(--bg);
    color: var(--fg);
    font-family: system-ui, -apple-system, "Hiragino Sans", "Noto Sans JP", sans-serif;
    line-height: 1.9;
    font-size: 16px;
  }
  main { max-width: 44rem; margin: 0 auto; }
  h1 {
    font-size: 2.25rem;
    font-weight: 400;
    letter-spacing: 0.08em;
    margin: 0 0 0.5rem;
  }
  .lede { color: var(--muted); margin: 0 0 3rem; }
  h2 {
    font-size: 1.1rem;
    font-weight: 600;
    margin: 3rem 0 0.75rem;
    padding-bottom: 0.4rem;
    border-bottom: 1px solid var(--rule);
  }
  h3 { font-size: 0.95rem; font-weight: 600; margin: 1.75rem 0 0.5rem; }
  p, ul { margin: 0 0 1rem; }
  ul { padding-left: 1.25rem; }
  li { margin-bottom: 0.35rem; }
  a { color: var(--accent); text-decoration: underline; text-underline-offset: 0.2em; }
  code {
    background: var(--code-bg);
    padding: 0.1em 0.35em;
    border-radius: 3px;
    font-size: 0.9em;
  }
  pre {
    background: var(--code-bg);
    padding: 0.9rem 1rem;
    border-radius: 4px;
    overflow-x: auto;
    line-height: 1.7;
  }
  pre code { background: none; padding: 0; }
  .note {
    border-left: 2px solid var(--rule);
    padding-left: 1rem;
    color: var(--muted);
  }
  footer {
    margin-top: 4rem;
    padding-top: 1rem;
    border-top: 1px solid var(--rule);
    color: var(--muted);
    font-size: 0.85rem;
  }
</style>
</head>
<body>
<main>

<h1>lain</h1>
<p class="lede">m1sk9 が管理している Discord サーバで使用できるチャット AI です．</p>

<h2>使用方法</h2>
<p>会話を始めるには <code>@lain</code> をメンションしてメッセージを送信します．</p>
<p>lain が閲覧権限・送信権限をもつテキストチャンネル・スレッドチャンネルで使用することができます．サーバのチャンネルでは必ずメンションが必要です．メンションの無い発言や，他の人宛のメンションには反応しません．</p>
<p>DM には対応していません．lain との会話はサーバのチャンネル上でのみ行えます．</p>

<h2>使用モデル・ツール</h2>
<p>モデルは Router 運用されているため，使用状況に合わせて自動選択されます．</p>
<p>選択されるモデルは次の通りです．</p>
<pre><code>qwen/qwen3.6-flash
qwen/qwen3.8-27b-free
qwen/qwen3.7-flash
deepseek/deepseek-v4-flash-free</code></pre>

<h3>できること</h3>
<ul>
  <li>お話</li>
  <li>簡単なタスク</li>
  <li>Web 検索</li>
</ul>

<h3>できないこと</h3>
<ul>
  <li>画像の認識</li>
  <li>音声による会話</li>
</ul>

<h2>メモリ機能</h2>
<p>lain は会話を通じて覚えたことを保持します．覚えておいてほしいことがあれば覚えてくれます．</p>
<p class="note">ただし<strong>メモリは lain 全体で 1 つ</strong>で，ユーザーごとには分かれていません．誰かが覚えさせたことは，他の人との会話でも参照されることがあります．個人的な情報を覚えさせないでください．<br>
会話の履歴自体はユーザーごとに独立しているため，他の人との会話の内容がそのまま見えることはありません．</p>

<h2>人格</h2>
<p>lain で使用している SOUL.md は <a href="https://github.com/m1sk9/infra/blob/main/ansible/roles/docker_compose_app/files/hermes/SOUL.md">こちら</a> から確認できます．</p>
<p>人格形成に使用しているのは <a href="https://www.nbcuni.co.jp/rondorobe/anime/lain/">Serial Experiments Lain の岩倉玲音</a> です．</p>

<h2>注意点</h2>
<ul>
  <li>現在試験運用中です．予告なくサービスを終了する可能性があります．</li>
  <li>Qwen，DeepSeek では会話内容がモデルの学習に使用される可能性があります．lain に機密情報などを渡さないようにしてください．</li>
  <li>m1sk9 が個人的に展開しているサービスです．クレジットをすべて消費したり無料枠を使い果たすと停止する可能性があります．
    <ul><li>あくまで趣味で公開しているものなので，仕事など自分のために使う場合は Claude や ChatGPT などのサブスクリプションをご利用ください．</li></ul>
  </li>
  <li>稼働状況は <a href="https://status.m1sk9.dev/">status.m1sk9.dev</a> で確認できます．</li>
</ul>

<footer>lain — <a href="https://m1sk9.dev">m1sk9.dev</a></footer>

</main>
</body>
</html>`;

export default {
  async fetch() {
    return new Response(HTML, {
      headers: {
        "content-type": "text/html;charset=UTF-8",
        "cache-control": "public, max-age=300",
        "x-content-type-options": "nosniff",
      },
    });
  },
};
