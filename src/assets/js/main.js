(() => {
  function history () {
    window.history.scrollRestoration && (window.history.scrollRestoration = "manual")
  }
  function runServiceWorker () {
    "serviceWorker" in navigator && navigator.serviceWorker.register("/assets/js/sw.bs.js")
  }

  history()
  runServiceWorker()
})()