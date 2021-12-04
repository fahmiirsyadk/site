const { fontFamily } = require('tailwindcss/defaultTheme');

module.exports = {
  purge: {
    content: ['./dist/**/*.html']
  },
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      fontFamily: {
        'sans': ['Inter Var', 'sans-serif'],
        'swear': ['Swear Banner', ...fontFamily.serif ],
      },
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
