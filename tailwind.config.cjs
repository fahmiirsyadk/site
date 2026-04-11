/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.purs", "./css/**/*.css"],
  darkMode: "class",
  theme: {
    extend: {},
  },
  plugins: [require("@tailwindcss/typography")],
};
