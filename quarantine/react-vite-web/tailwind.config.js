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
          // Playtomic-inspired palette
          primary: '#C8F04D',      // verde lima neón (CTA principal)
          primaryDark: '#a8cc30',  // hover del primario
          dark: '#0A0A0A',         // fondo principal casi negro
          surface: '#141414',      // cards y superficies
          surface2: '#1C1C1C',     // superficie secundaria
          border: '#2A2A2A',       // bordes sutiles
          muted: '#6B6B6B',        // texto secundario
          light: '#F5F5F5',        // texto principal
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Sora', 'system-ui', 'sans-serif'],
      },
      animation: {
        'fade-in': 'fadeIn 0.4s ease-out',
        'slide-up': 'slideUp 0.4s ease-out',
        'pulse-glow': 'pulseGlow 2s infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(16px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 8px rgba(200, 240, 77, 0.3)' },
          '50%': { boxShadow: '0 0 20px rgba(200, 240, 77, 0.6)' },
        },
      },
    },
  },
  plugins: [],
}
