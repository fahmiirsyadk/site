/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.hs", "./src/**/*.hs", "./css/**/*.css"],
  darkMode: "class",
  theme: {
    extend: {},
  },
  plugins: [require("@tailwindcss/typography")],
};