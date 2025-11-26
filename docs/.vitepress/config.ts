import { defineConfig } from 'vitepress';

// https://vitepress.dev/reference/site-config
export default defineConfig({
  srcDir: 'src',
  title: "m1sk9's infra docs",
  titleTemplate: ':title - infra.m1sk9.dev',
  description: 'infra.m1sk9.dev documentation',
  lang: 'ja',
  cleanUrls: true,
  outDir: './build',
  lastUpdated: true,
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'ガイド', link: '/guide/getting-started' },
      { text: 'リファレンス', link: "/reference" }
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'はじめる',
          link: '/guide/getting-started',
          },
          {
            text: "利用ルール",
            link: "/guide/rule"
          },
          {
            text: "トラブルシューティング",
            link: "/guide/troubleshooting"
          },
          {
            text: "FAQ",
            link: "/guide/faq"
          },
          {
            text: 'Tailscale',
            items: [
              {
                text: "CLI クイックリファレンス", link: '/guide/tailscale/cli'
              },
              {
                text: "Exit Node を使用する", link: '/guide/tailscale/exit-node'
              },
              {
                text: "Tailscale SSH を使用する", link: '/guide/tailscale/ssh'
              }
            ]
          },
          {
            text: 'withoutbg (背景除去AI)',
            link: '/guide/withoutbg',
          },
          {
            text: 'サーバガイド',
            items: [
              {
                text: "s1",
                link: "/guide/server/s1",
                items: [
                  {
                    text: "使用ポート番号", link: '/guide/server/s1/ports'
                  }
                ]
              }
            ]
          }
      ],
      '/reference/': [
        {
          text: 'Bot',
          items: [
            {
              text: "babyrite",
              link: "/reference/bot/babyrite",
            }
          ]
        }
      ]
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/m1sk9/infra' },
    ],
  },
});
