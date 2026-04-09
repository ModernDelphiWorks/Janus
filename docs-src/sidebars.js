const sidebars = {
  docsSidebar: [
    {
      type: 'category',
      label: 'Projects',
      items: [{ type: 'link', label: 'Janus', href: '/janus/' }],
    },
  ],
  janusSidebar: [
    {
      type: 'category',
      label: 'Janus',
      link: { type: 'doc', id: 'janus/index' },
      items: [
        {
          type: 'category',
          label: 'Documentacao Tecnica',
          items: [
            'janus/introduction',
            {
              type: 'category',
              label: 'Getting Started',
              items: ['janus/getting-started/quickstart'],
            },
            {
              type: 'category',
              label: 'Architecture',
              items: ['janus/architecture/overview', 'janus/architecture/runtime-flow'],
            },
            {
              type: 'category',
              label: 'Guides',
              items: [
                'janus/guides/middleware',
                'janus/guides/criteria-fluentsql',
                'janus/guides/lazy-loading',
              ],
            },
            {
              type: 'category',
              label: 'Reference',
              items: ['janus/reference/api'],
            },
            {
              type: 'category',
              label: 'Tests & Support',
              items: ['janus/tests/overview', 'janus/troubleshooting/common-errors'],
            },
          ],
        },
        {
          type: 'category',
          label: 'Manual do Usuario',
          items: [
            'janus/user/index',
            'janus/user/introduction',
            {
              type: 'category',
              label: 'Getting Started',
              items: ['janus/user/getting-started/quickstart'],
            },
            {
              type: 'category',
              label: 'Guides',
              items: [
                'janus/user/guides/primeiro-crud-com-dataset',
                'janus/user/guides/operacao-master-detail',
                'janus/user/guides/objectset',
                'janus/user/guides/consultas-personalizadas',
                'janus/user/guides/nullable',
                'janus/user/guides/lazy-loading',
                'janus/user/guides/livebindings',
                'janus/user/guides/monitor-sql',
                'janus/user/guides/eventos-middleware',
                'janus/user/guides/codegen',
                'janus/user/guides/json',
                'janus/user/guides/restful',
              ],
            },
            {
              type: 'category',
              label: 'Reference',
              items: ['janus/user/reference/configuration'],
            },
            {
              type: 'category',
              label: 'Troubleshooting',
              items: ['janus/user/troubleshooting/common-errors'],
            },
          ],
        },
      ],
    },
  ],
};

module.exports = sidebars;