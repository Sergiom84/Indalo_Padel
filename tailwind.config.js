/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        padel: {
          primary: '#0d9488',
          secondary: '#0284c7',
          accent: '#14b8a6',
          dark: '#0f172a',
          surface: '#1e293b',
          light: '#f0fdfa',
        },
      },
      backgroundColor: {
        'padel-primary': '#0d9488',
        'padel-secondary': '#0284c7',
        'padel-dark': '#0f172a',
        'padel-surface': '#1e293b',
        'padel-light': '#f0fdfa',
        'padel-10': 'rgba(13, 148, 136, 0.1)',
        'padel-20': 'rgba(13, 148, 136, 0.2)',
      },
      borderColor: {
        'padel-20': 'rgba(13, 148, 136, 0.2)',
        'padel-40': 'rgba(13, 148, 136, 0.4)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Sora', 'system-ui', 'sans-serif'],
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.5s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
