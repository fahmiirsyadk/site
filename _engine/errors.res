open Utils

// no main function declared
let noMainFunctionDeclared = (path) => {
  open Kleur
  Js.log(kleur->bold()->red("Look like the main function no declared, here some tips to write them:"))
  Js.log(kleur->blue()->underline(`>>> Found at: ${path}`))
  Js.log(`
module H = Mana.HTML

let main () =
  H.html [] [
    H.body [] [
      H.h1 [] (H.text "its me!")
    ]
  ]
`)
}
// not valid syntax on main function
let mainFunctionEmpty = ()