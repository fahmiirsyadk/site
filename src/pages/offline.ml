module H = Mana.HTML
module P = Mana.Property

let styles = "
* {
  margin: 0;
  padding: 0;
}

section {
  align-items: center;
  background: #000;
  box-sizing: border-box;
  color: #fff;
  cursor: default;
  display: flex;
  font-family: 'Arial';
  font-size: 1.6rem;
  height: 100%;
  justify-content: center;
  left: 0;
  padding: 4rem;
  position: fixed;
  text-align: center;
  top: 0;
  width: 100%;
  z-index: 4;
}"

let head =
  H.head [
  ] [
    H.meta [P.charset "UTF-8"] [];
    H.title [] (H.text "Fahmiirsyadk");
    H.style [] (H.text styles);
  ]

let body = 
  H.body [] [
    H.section [] [
      H.h2 [] 
        ("This experience is only available with internet connection" |> H.text)
    ]
  ]  

let html () =
  H.html [] [
    head;
    body;
  ]