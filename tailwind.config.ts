import type { Config } from 'tailwindcss'

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#17201f',
        route: '#0f9d8a',
        sky: '#e8f2ef',
        amber: '#f2a93b',
        rose: '#d9535f',
      },
      fontFamily: {
        sans: ['Cairo', 'Noto Sans Arabic', 'Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        soft: '0 10px 30px rgba(23, 32, 31, 0.08)',
        lift: '0 18px 40px rgba(23, 32, 31, 0.14)',
      },
      keyframes: {
        rise: { '0%': { opacity: '0', transform: 'translateY(8px)' }, '100%': { opacity: '1', transform: 'translateY(0)' } },
        pop: { '0%': { opacity: '0', transform: 'scale(.96)' }, '100%': { opacity: '1', transform: 'scale(1)' } },
      },
      animation: {
        rise: 'rise .35s ease-out both',
        pop: 'pop .25s ease-out both',
      },
    },
  },
  plugins: [],
} satisfies Config
