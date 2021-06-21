(() => {
  function history () {
    window.history.scrollRestoration && (window.history.scrollRestoration = "manual")
  }
  function runServiceWorker () {
    "serviceWorker" in navigator && navigator.serviceWorker.register("/sw.js")
  }

  history()
  runServiceWorker()
})()