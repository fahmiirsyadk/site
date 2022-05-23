with import <nixpkgs> {};

mkShell {
  buildInputs = [
    nodejs
    yarn
  ];
  shellHook = ''
    export PATH="`pwd`/node_modules/.bin:$PATH"
  '';
}