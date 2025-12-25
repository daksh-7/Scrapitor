import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { resolve } from 'path';

export default defineConfig({
  plugins: [svelte()],
  resolve: {
    alias: {
      $lib: resolve(__dirname, './src/lib'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/logs': 'http://localhost:5000',
      '/tunnel': 'http://localhost:5000',
      '/health': 'http://localhost:5000',
      '/parser-settings': 'http://localhost:5000',
      '/parser-tags': 'http://localhost:5000',
      '/parser-rewrite': 'http://localhost:5000',
    },
  },
  build: {
    outDir: '../app/static/dist',
    emptyOutDir: true,
  },
});

