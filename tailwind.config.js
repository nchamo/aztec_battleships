/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      animation: {
        'spin-slow': 'spin 3s linear infinite',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'ping-slow': 'ping 2s cubic-bezier(0, 0, 0.2, 1) infinite',
        'wave': 'wave 8s ease-in-out infinite',
        'float': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        wave: {
          '0%, 100%': { transform: 'translateY(0) translateX(0)' },
          '25%': { transform: 'translateY(-2px) translateX(2px)' },
          '50%': { transform: 'translateY(0) translateX(4px)' },
          '75%': { transform: 'translateY(2px) translateX(2px)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-10px)' },
        },
      },
      colors: {
        ocean: {
          50: '#e6f4f9',
          100: '#c1e3f0',
          200: '#98d1e6',
          300: '#6ebfdc',
          400: '#4faed2',
          500: '#319dc8',
          600: '#2a8db5',
          700: '#1e6b8a',
          800: '#1a5a74',
          900: '#0f3a4d',
          950: '#0a2533',
        },
      },
      backgroundImage: {
        'ocean-gradient': 'linear-gradient(180deg, #0f172a 0%, #1e3a5f 50%, #0f172a 100%)',
        'ocean-waves': 'url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 1440 320\'%3E%3Cpath fill=\'%231e3a5f\' fill-opacity=\'0.3\' d=\'M0,160L48,176C96,192,192,224,288,213.3C384,203,480,149,576,138.7C672,128,768,160,864,186.7C960,213,1056,235,1152,218.7C1248,203,1344,149,1392,122.7L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z\'%3E%3C/path%3E%3C/svg%3E")',
      },
    },
  },
  plugins: [],
}
