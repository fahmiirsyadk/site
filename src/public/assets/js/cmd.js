console.log("There is a new command available: ls");

let historyCmd = "";

let terminal = document.getElementById("terminal");
let inputPanel = document.getElementById("input-panel");
let inputCmd = document.getElementById("input-cmd");
let terminalBtn = document.getElementById("terminal-btn");

const printElement = (text, element) => {
  const placeholder = document.createElement(element);
  placeholder.innerHTML = text;
  return placeholder;
};

terminalBtn.addEventListener("click", () => {
	if (terminal.classList.contains("hidden")) {
		terminal.classList.toggle("hidden");
	} else {
		terminal.classList.add("hidden");
	}
});

inputCmd.addEventListener("keypress", function (e) {
  if (e.key === "Enter") {
    let cmd = inputCmd.value;
    inputCmd.value = "";
    historyCmd = cmd;
    inputPanel.before(printElement(`~# ${cmd}`, "p"));
    if (cmd === "clear") {
      terminal.innerHTML = "";
      // append inputPanel to terminal
      terminal.appendChild(inputPanel);
      // focus on inputCmd
      inputCmd.focus();
    } else if (cmd === "fullscreen") {
      // fullscreen the terminal
      terminal.classList.remove("max-w-fit");
      terminal.style.left = "0";
      terminal.style.background = "#dfdfdf63";
      terminal.style.backdropFilter = "blur(10px)";
    } else if (cmd === "exit") {
      // exit the fullscreen
      terminal.classList.add("max-w-fit");
      terminal.style.left = "auto";
      terminal.style.background = "transparent";
      terminal.style.backdropFilter = "none";
    } else if (cmd === "help") {
      inputPanel.before(
        printElement("help.........everyone know this command", "p")
      );
      inputPanel.before(printElement("clear........clear all logs", "p"));
      inputPanel.before(
        printElement("fullscreen...activate fullscreen terminal", "p")
      );
      inputPanel.before(
        printElement("exit.........exit fullscreen terminal", "p")
      );
    } else if (cmd === "ls") {
      return;
    } else if (cmd === "ls -a" || cmd === "ls -la") {
      inputPanel.before(printElement(".", "p"));
      inputPanel.before(printElement("..", "p"));
      inputPanel.before(printElement(".secret.sh", "p"));
    } else {
      inputPanel.before(printElement(`Command ${cmd} not found`, "p"));
    }
  }
});
