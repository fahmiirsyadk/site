const requestData = async (url) => {
  let res = await window.fetch(url, {
    headers: {
      "X-Requested-With": "XMLHttpRequest"
    }
  })
  return res.text()
}

const changeDom = (domNodes) => {
  let doc = document.createElement("div");
  const containerOri = document.querySelector('.container');
  doc.innerHTML = domNodes;
  const title = doc.getElementsByTagName("title")[0].textContent
  const container = doc.querySelector(".container");
  containerOri.parentNode
    .replaceChild(container, containerOri);

  document.title = title
}

const historyChange = (url) => {
  window.history.pushState(null, null, url)
}

const addLinksEventsListenener = () => {
  const nodes = document.querySelectorAll("a");
  const links = Array.from(nodes);
  links.length > 0 && links.forEach(link => {
    const { href } = link
    console.log({
      link: href,
      index: href.indexOf(window.location.origin),
      window: window.location.origin
    })
    href.indexOf(window.location.origin) > -1 ? link.onclick = e => {
      e.preventDefault()
      e.stopPropagation()
      onChangePage(href, true)
    } : false
  })
}

async function onChangePage(newUrl, updatePage) {
  let dom = await requestData(newUrl)
  updatePage && historyChange(newUrl)
  changeDom(dom)
  addLinksEventsListenener()
}

window.onpopstate = function(e) {
  onChangePage(e.target.location.href, false)
}

addLinksEventsListenener()