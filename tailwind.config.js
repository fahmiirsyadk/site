const { fontFamily } = require('tailwindcss/defaultTheme');

module.exports = {
  content: ['./dist/**/*.html'],
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
  plugins: [
    require('@tailwindcss/typography')
  ],
}
