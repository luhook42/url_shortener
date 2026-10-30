import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ command, mode }) => {
  // Vite inlines every VITE_* variable into the built JS. A bundle built with
  // VITE_API_TOKEN set hands the API token to anyone who can load the page.
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  if (command === 'build' && env.VITE_API_TOKEN) {
    throw new Error(
      'Refusing to build with VITE_API_TOKEN set: it would be embedded in dist/. ' +
        'The dashboard is for local `npm run dev` only.',
    )
  }
  return { plugins: [react()] }
})
