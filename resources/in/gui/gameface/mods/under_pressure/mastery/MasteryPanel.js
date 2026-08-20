import { ModelObserver } from "../../libs/model.js";

const observer = ModelObserver();
const BASE_W = 210;
const BASE_H = 78;
const EXPANDED_H = 132;
const ICONS = [
  "",
  "img://gui/maps/icons/achievement/48x48/markOfMastery1.png",
  "img://gui/maps/icons/achievement/48x48/markOfMastery2.png",
  "img://gui/maps/icons/achievement/48x48/markOfMastery3.png",
  "img://gui/maps/icons/achievement/48x48/markOfMastery4.png"
];
const LABELS = ["—","III","II","I","M"];
let dragging=false,expanded=true,lastX=0,lastY=0,pendingX=0,pendingY=0,dragFrame=0;

function resizeSurface(){const h=expanded?EXPANDED_H:BASE_H;try{if(viewEnv&&viewEnv.freezeTextureBeforeResize)viewEnv.freezeTextureBeforeResize();}catch(e){}try{if(viewEnv){if(viewEnv.resizeViewPx)viewEnv.resizeViewPx(BASE_W,h);else if(viewEnv.resizeViewRem)viewEnv.resizeViewRem(BASE_W,h);}}catch(e){}}
function pointerPosition(e){try{if(viewEnv&&viewEnv.getMouseGlobalPositionPx){const p=viewEnv.getMouseGlobalPositionPx();if(p)return{x:Number(p.x)||0,y:Number(p.y)||0};}}catch(err){}return{x:Number(e&&e.screenX)||Number(e&&e.clientX)||0,y:Number(e&&e.screenY)||Number(e&&e.clientY)||0};}
function command(name,args){try{const m=observer.model;if(m&&typeof m[name]==="function")m[name](args||{});}catch(e){}}
function dragCommand(action,x,y){command("onDrag",{action:action,mouseX:Number(x)||0,mouseY:Number(y)||0});}
function flushDrag(){dragFrame=0;if(dragging)dragCommand("move",pendingX,pendingY);}
function setExpanded(root,value){expanded=!!value;root.classList.toggle("expanded",expanded);const b=root.querySelector(".expand-toggle");if(b)b.title=expanded?"Згорнути пороги":"Показати пороги";resizeSurface();}
function fmt(v,loading){if(loading)return"…";const n=Math.max(0,Math.round(Number(v)||0));return n>0?n.toLocaleString("en-US"):"—";}
function ensureRoot(){let root=document.getElementById("up-mastery-root");if(root)return root;root=document.createElement("div");root.id="up-mastery-root";root.innerHTML='<div class="garage-card"><button class="expand-toggle" type="button"><span class="chevron"></span></button><button class="stats-button" type="button" title="Статистика"><span class="bar b1"></span><span class="bar b2"></span><span class="bar b3"></span></button><div class="mastery-icon-wrap"><img class="mastery-icon"/></div><div class="mastery-main"><div class="mastery-label">Майстерність</div><div class="mastery-value">—</div><div class="tank-name"></div></div><div class="expanded-details"><div class="threshold-cell t3"><span>III</span><strong class="third">…</strong></div><div class="threshold-cell t2"><span>II</span><strong class="second">…</strong></div><div class="threshold-cell t1"><span>I</span><strong class="first">…</strong></div><div class="threshold-cell tm"><span>M</span><strong class="ace">…</strong></div></div></div>';document.body.appendChild(root);setExpanded(root,true);const toggle=root.querySelector(".expand-toggle"),stats=root.querySelector(".stats-button"),card=root.querySelector(".garage-card");toggle.onclick=e=>{setExpanded(root,!expanded);e.stopPropagation();};stats.onclick=e=>{command("onOpenStats",{});e.stopPropagation();};card.addEventListener("mousedown",e=>{if(Number(e.button)!==0)return;let t=e.target;while(t&&t!==card){if(String(t.tagName||"").toLowerCase()==="button")return;t=t.parentNode;}const p=pointerPosition(e);dragging=true;pendingX=p.x;pendingY=p.y;lastX=p.x;lastY=p.y;root.classList.add("dragging");dragCommand("start",p.x,p.y);e.preventDefault();e.stopPropagation();});document.addEventListener("mousemove",e=>{if(!dragging)return;const p=pointerPosition(e),dx=p.x-lastX,dy=p.y-lastY;if(dx||dy){lastX=p.x;lastY=p.y;pendingX=p.x;pendingY=p.y;if(!dragFrame)dragFrame=requestAnimationFrame(flushDrag);}e.preventDefault();});document.addEventListener("mouseup",e=>{if(!dragging)return;const p=pointerPosition(e);pendingX=p.x;pendingY=p.y;flushDrag();dragging=false;root.classList.remove("dragging");dragCommand("end",p.x,p.y);e.preventDefault();});return root;}
function render(model){const root=ensureRoot();if(!model||!model.visible){root.style.display="none";return;}root.style.display="";const mastery=Math.max(0,Math.min(4,Number(model.mastery)||0));const img=root.querySelector(".mastery-icon");if(ICONS[mastery]){img.src=ICONS[mastery];img.style.display="";}else img.style.display="none";root.querySelector(".mastery-value").textContent=LABELS[mastery]||"—";root.querySelector(".tank-name").textContent=String(model.tankName||"");root.querySelector(".third").textContent=fmt(model.thirdClass,model.loading);root.querySelector(".second").textContent=fmt(model.secondClass,model.loading);root.querySelector(".first").textContent=fmt(model.firstClass,model.loading);root.querySelector(".ace").textContent=fmt(model.aceTanker,model.loading);root.classList.toggle("no-data",!model.hasXp&&!model.loading);}
resizeSurface();observer.onUpdate(render);observer.subscribe();render(observer.model);
