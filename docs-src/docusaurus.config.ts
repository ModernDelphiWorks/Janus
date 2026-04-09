import type { Config } from '@docusaurus/types';

const config: Config = {
  title: 'Janus Docs',
  url: 'https://example.com',
  baseUrl: '/',
  favicon: 'img/favicon.ico',
  organizationName: 'ModernDelphiWorks',
  projectName: 'Janus',
  presets: [
    [
      'classic',
      {
        docs: {
          path: 'docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
        },
        blog: false,
        pages: false,
      },
    ],
  ],
  themeConfig: {
    navbar: {
      title: 'Janus',
      items: [
        {
          label: 'Projects',
          position: 'left',
          items: [{ to: '/janus/', label: 'Janus' }],
        },
      ],
    },
  },
};

export default config;
