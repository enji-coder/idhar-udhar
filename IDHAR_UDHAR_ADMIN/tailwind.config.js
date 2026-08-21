import { theme, shadows } from './src/config/theme.js';

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: theme.veryLightCyan,
          100: theme.lightCyan,
          200: '#B8F1F6',
          300: '#7FE6F0',
          400: '#3FD6E8',
          500: theme.primaryCyan,
          600: theme.secondaryCyan,
          700: theme.primaryDark,
          800: '#087A8C',
          900: '#055A66',
        },
        canvas: theme.background,
        surface: theme.surface,
        line: theme.border,
        success: theme.success,
        warning: theme.warning,
        danger: theme.error,
        cyan: theme.cyan,
        ink: {
          DEFAULT: theme.textPrimary,
          muted: theme.textSecondary,
          soft: '#8A97AB',
        },
      },
      boxShadow: {
        card: shadows.card,
        'card-hover': shadows.cardHover,
        sidebar: shadows.sidebar,
        floating: shadows.floating,
      },
      borderRadius: {
        card: '20px',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'Segoe UI', 'sans-serif'],
      },
      keyframes: {
        pulseDot: {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.45', transform: 'scale(1.35)' },
        },
      },
      animation: {
        pulseDot: 'pulseDot 1.6s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};
