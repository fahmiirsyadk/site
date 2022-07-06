const { fontFamily } = require('tailwindcss/defaultTheme');

module.exports = {
  content: ['./dist/**/*.html', './dist/*.html'],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['Inter', ...fontFamily.sans],
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
