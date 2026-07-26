import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const isProduction = process.env.NODE_ENV === 'production';

const config: Config = {
  title: 'PSGenerator',
  tagline: 'Generate native PowerShell modules for containerized applications',
  url: isProduction
    ? 'https://psgenerator.subzerodev.com'
    : 'http://localhost:3000',
  baseUrl: '/',
  organizationName: 'The-Running-Dev',
  projectName: 'SubZeroDev.PSGenerator',
  trailingSlash: false,

  onBrokenLinks: 'throw',

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {defaultLocale: 'en', locales: ['en']},

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebar.ts',
          routeBasePath: '/',
        },
        blog: false,
        // The base image ships the template's own landing, portfolio, CV and
        // demo pages under src/pages. This project serves its documentation
        // from the site root and provides its own landing page, so the pages
        // plugin is disabled rather than publishing that unrelated content.
        pages: false,
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'PSGenerator',
      items: [
        {type: 'docSidebar', sidebarId: 'docs', position: 'left', label: 'Docs'},
        {
          href: 'https://github.com/The-Running-Dev/SubZeroDev.PSGenerator',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      copyright: `Copyright © ${new Date().getFullYear()} The Running Dev`,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
