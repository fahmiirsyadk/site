(() => {
  function history () {
    window.history.scrollRestoration && (window.history.scrollRestoration = "manual")
  }
  function runServiceWorker () {
    "serviceWorker" in navigator && navigator.serviceWorker.register("/service-worker.bs.js")
  }

  history()
  runServiceWorker()
})()