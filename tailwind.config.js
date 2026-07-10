/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.hs", "./src/**/*.hs", "./css/**/*.css"],
  darkMode: "class",
  theme: {
    extend: {
      typography: {
        DEFAULT: {
          css: {
            "--tw-prose-pre-code": "#404040",
            "--tw-prose-pre-bg": "#ffffff",
          },
        },
        neutral: {
          css: {
            "--tw-prose-pre-code": "#404040",
            "--tw-prose-pre-bg": "#ffffff",
          },
        },
      },
    },
  },
  plugins: [require("@tailwindcss/typography")],
};
