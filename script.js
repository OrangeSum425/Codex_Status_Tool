const refreshButton = document.querySelector("#refreshButton");
const fiveHourPercent = document.querySelector("#fiveHourPercent");
const fiveHourStatus = document.querySelector("#fiveHourStatus");
const resetCountdown = document.querySelector("#resetCountdown");
const dial = document.querySelector(".dial");

const state = {
  fiveHourPercent: 68,
  resetSeconds: 4703,
};

function formatCountdown(totalSeconds) {
  const hours = Math.floor(totalSeconds / 3600).toString().padStart(2, "0");
  const minutes = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, "0");
  const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, "0");
  return `${hours}:${minutes}:${seconds}`;
}

function render() {
  const ratio = Math.max(0, Math.min(100, state.fiveHourPercent)) / 100;
  dial.style.setProperty("--value", ratio.toFixed(2));
  fiveHourPercent.textContent = `${Math.round(state.fiveHourPercent)}%`;
  resetCountdown.textContent = formatCountdown(Math.max(0, state.resetSeconds));

  if (state.fiveHourPercent < 20) {
    fiveHourStatus.textContent = "Low";
    dial.style.setProperty("--green", "#ff7d93");
  } else if (state.fiveHourPercent < 45) {
    fiveHourStatus.textContent = "Careful";
    dial.style.setProperty("--green", "#f6c568");
  } else {
    fiveHourStatus.textContent = "Ready";
    dial.style.setProperty("--green", "#7be495");
  }
}

refreshButton.addEventListener("click", render);

setInterval(() => {
  state.resetSeconds = Math.max(0, state.resetSeconds - 1);
  render();
}, 1000);

render();
