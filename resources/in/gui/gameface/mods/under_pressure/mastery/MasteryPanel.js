import { ModelObserver } from "../../libs/model.js";

const observer = ModelObserver();
const SURFACE_W = 355;
const SURFACE_H = 80;
const SURFACE_REASSERT_MS = 4000;
const ICONS = [
    "img://gui/maps/icons/achievement/48x48/markOfMastery1.png",
    "img://gui/maps/icons/achievement/48x48/markOfMastery2.png",
    "img://gui/maps/icons/achievement/48x48/markOfMastery3.png",
    "img://gui/maps/icons/achievement/48x48/markOfMastery4.png"
];
const MARK_PCTS = ["65%", "85%", "95%", "100%"];

function resizeSurface() {
    try {
        if (typeof viewEnv !== "undefined" && viewEnv.freezeTextureBeforeResize)
            viewEnv.freezeTextureBeforeResize();
    } catch (e) {}
    try {
        if (typeof viewEnv !== "undefined" && viewEnv.resizeViewRem)
            viewEnv.resizeViewRem(SURFACE_W, SURFACE_H);
    } catch (e) {
        console.error("Under Pressure Mastery surface resize failed", e);
    }
}

function callCommand(name, args) {
    try {
        const model = observer.model;
        if (model && typeof model[name] === "function")
            model[name](args || {});
    } catch (e) {
        console.error("Under Pressure Mastery command failed", name, e);
    }
}

function fmtNumber(value) {
    const n = Math.max(0, Math.round(Number(value) || 0));
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

function cellValue(value, hasData, loading, noData) {
    if (loading) return "...";
    if (!hasData || !(Number(value) > 0)) return noData || "N/A";
    return fmtNumber(value);
}

function makeCell(i) {
    return '<div class="up-cell c' + i + '">' +
        '<img class="up-mastery-icon" src="' + ICONS[i] + '" />' +
        '<span class="up-xp-value"></span>' +
        '<span class="up-moe-pct">' + MARK_PCTS[i] + '</span>' +
        '<span class="up-moe-value"></span>' +
        '</div>';
}

let pointerDown = null;
let pointerMoved = false;

function bindInteraction(panel) {
    panel.addEventListener("mousedown", e => {
        if (e.button !== 0) return;
        pointerDown = { x: e.clientX, y: e.clientY };
        pointerMoved = false;
        callCommand("onDrag", { phase: "start" });
    });

    document.addEventListener("mousemove", e => {
        if (!pointerDown) return;
        const dx = e.clientX - pointerDown.x;
        const dy = e.clientY - pointerDown.y;
        if (dx * dx + dy * dy > 36) pointerMoved = true;
    });

    document.addEventListener("mouseup", e => {
        if (!pointerDown || e.button !== 0) return;
        callCommand("onDrag", { phase: "end" });
        const click = !pointerMoved;
        pointerDown = null;
        pointerMoved = false;
        if (click) callCommand("onNextMode", {});
    });
}

function ensureRoot() {
    let root = document.getElementById("up-mastery-root");
    if (root) return root;

    root = document.createElement("div");
    root.id = "up-mastery-root";
    let cells = "";
    for (let i = 0; i < 4; i++) cells += makeCell(i);
    root.innerHTML =
        '<div class="up-panel">' +
        '  <div class="up-background"></div>' +
        '  <div class="up-row up-mastery-row">' + cells + '</div>' +
        '  <div class="up-row up-marks-row">' + cells + '</div>' +
        '</div>';
    document.body.appendChild(root);

    const masteryCells = root.querySelectorAll(".up-mastery-row .up-cell");
    const marksCells = root.querySelectorAll(".up-marks-row .up-cell");
    for (let i = 0; i < masteryCells.length; i++) {
        masteryCells[i].querySelector(".up-moe-pct").style.display = "none";
        masteryCells[i].querySelector(".up-moe-value").style.display = "none";
    }
    for (let i = 0; i < marksCells.length; i++) {
        marksCells[i].querySelector(".up-mastery-icon").style.display = "none";
        marksCells[i].querySelector(".up-xp-value").style.display = "none";
    }

    bindInteraction(root.querySelector(".up-panel"));
    return root;
}

function render(model) {
    const root = ensureRoot();
    const d = model;
    if (!d || !d.visible) {
        root.style.display = "none";
        return;
    }
    root.style.display = "";

    let mode = Number(d.mode);
    if (mode !== 1 && mode !== 2) mode = 0;
    root.classList.toggle("single", mode !== 0);
    root.classList.toggle("mastery-only", mode === 1);
    root.classList.toggle("marks-only", mode === 2);

    const xp = [d.thirdClass, d.secondClass, d.firstClass, d.aceTanker];
    const moe = [d.p65, d.p85, d.p95, d.p100];
    const xpEls = root.querySelectorAll(".up-mastery-row .up-xp-value");
    const moeEls = root.querySelectorAll(".up-marks-row .up-moe-value");
    const loading = !!d.loading;
    const noData = d.noData || "N/A";

    for (let i = 0; i < 4; i++) {
        const xpText = cellValue(xp[i], !!d.hasXp, loading, noData);
        const moeText = cellValue(moe[i], !!d.hasMoe, loading, noData);
        xpEls[i].textContent = xpText;
        xpEls[i].classList.toggle("up-dim", !d.hasXp && !loading);
        moeEls[i].textContent = moeText;
        moeEls[i].classList.toggle("up-dim", !d.hasMoe && !loading);
    }
}

engine.whenReady.then(() => {
    resizeSurface();
    setInterval(resizeSurface, SURFACE_REASSERT_MS);
    observer.onUpdate(render);
    observer.subscribe();
    render(observer.model);
});
