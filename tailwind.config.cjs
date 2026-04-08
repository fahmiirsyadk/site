/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.purs", "./css/**/*.css"],
  darkMode: "media",
  theme: {
    extend: {},
  },
  plugins: [require("@tailwindcss/typography")],
};
