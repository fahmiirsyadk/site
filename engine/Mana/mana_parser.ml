
let dynamicData = "blog"
let importFunction = [%raw {|
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
|}]

let executeFunction = importFunction ( "/home/fahmiirsyadk/Developments/ocaml/site/pages/" ^ dynamicData ^ ".bs.js") Parser.postMd

let _ = executeFunction |> Parser.generatePage "" "jajal"
