const video = document.getElementById("camera");
const analysisCanvas = document.getElementById("analysisCanvas");
const overlayCanvas = document.getElementById("overlayCanvas");
const adviceCard = document.getElementById("adviceCard");
const adviceText = document.getElementById("adviceText");
const recipientText = document.getElementById("recipient");
const startButton = document.getElementById("startButton");
const demoButton = document.getElementById("demoButton");
const debugButton = document.getElementById("debugButton");
const debugPanel = document.getElementById("debugPanel");
const measurementOutput = document.getElementById("measurementOutput");
const issueOutput = document.getElementById("issueOutput");
const manualBox = document.getElementById("manualBox");
const cameraToggle = document.getElementById("cameraToggle");

const state = {
  stream: null,
  model: null,
  modelStatus: "not_loaded",
  facingMode: "environment",
  running: false,
  demoMode: false,
  debug: false,
  lastInstruction: null,
  lastInstructionAt: 0,
  stableIssueKey: null,
  stableSince: 0,
  roll: 0,
  lastFrameAt: 0,
  lastBox: null,
};

const thresholds = {
  minIssueMs: 650,
  minInstructionMs: 1500,
  repeatCooldownMs: 2800,
  tooCloseArea: 0.48,
  tooFarArea: 0.055,
  tooMuchHeadroom: 0.16,
  tooLittleHeadroom: 0.025,
  edgePad: 0.025,
  rollDegrees: 4,
  darkFace: 70,
  backlitDelta: 55,
  minReadyMs: 450,
};

startButton.addEventListener("click", startCamera);
cameraToggle.addEventListener("click", switchCamera);
debugButton.addEventListener("click", () => {
  state.debug = !state.debug;
  debugPanel.hidden = !state.debug;
});
demoButton.addEventListener("click", () => {
  state.demoMode = !state.demoMode;
  manualBox.hidden = !state.demoMode;
  demoButton.textContent = state.demoMode ? "Auto Detect" : "Demo Box";
});

window.addEventListener("resize", resizeCanvases);
window.addEventListener("deviceorientation", (event) => {
  if (typeof event.gamma === "number") {
    state.roll = clamp(event.gamma, -35, 35);
  }
});

makeManualBoxDraggable();
setAdvice("Camera", "Start camera", "waiting");

async function startCamera() {
  try {
    setAdvice("Camera", "Starting camera...", "waiting");
    await stopCamera();
    state.stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: {
        facingMode: state.facingMode,
        width: { ideal: 1280 },
        height: { ideal: 720 },
      },
    });
    video.srcObject = state.stream;
    await video.play();
    resizeCanvases();
    state.running = true;
    startButton.textContent = "Restart";
    loadModel();
    requestAnimationFrame(loop);
  } catch (error) {
    console.error(error);
    setAdvice("Camera", "Camera permission needed", "danger");
  }
}

async function switchCamera() {
  state.facingMode = state.facingMode === "environment" ? "user" : "environment";
  if (state.running) {
    await startCamera();
  }
}

async function stopCamera() {
  if (!state.stream) return;
  state.stream.getTracks().forEach((track) => track.stop());
  state.stream = null;
}

async function loadModel() {
  if (state.model || state.modelStatus === "loading") return;
  state.modelStatus = "loading";
  try {
    if (!window.cocoSsd) throw new Error("COCO-SSD script was not loaded.");
    state.model = await window.cocoSsd.load({ base: "lite_mobilenet_v2" });
    state.modelStatus = "ready";
  } catch (error) {
    console.warn(error);
    state.modelStatus = "unavailable";
    state.demoMode = true;
    manualBox.hidden = false;
    demoButton.textContent = "Auto Detect";
    setAdvice("Camera", "Use demo box", "warning");
  }
}

async function loop(now) {
  if (!state.running) return;
  resizeCanvases();

  const shouldAnalyze = now - state.lastFrameAt > 220;
  if (shouldAnalyze) {
    state.lastFrameAt = now;
    const measurements = await measureScene();
    const issues = findIssues(measurements);
    const selected = selectInstruction(issues, now);
    drawOverlay(measurements, issues, selected);
    renderDebug(measurements, issues);
    if (selected) {
      setAdvice(selected.recipient, selected.instruction, selected.tone);
    }
  }

  requestAnimationFrame(loop);
}

async function measureScene() {
  const frame = getFrameRect();
  const box = state.demoMode ? getManualBoxMeasurement(frame) : await detectPerson(frame);
  state.lastBox = box || state.lastBox;

  const luminance = sampleLuminance(box);
  const motion = Math.abs(state.roll) > thresholds.rollDegrees ? "tilted" : "stable";

  return {
    timestamp: Date.now(),
    modelStatus: state.modelStatus,
    frame,
    personBox: box,
    faceBox: estimateFaceBox(box),
    faceLuminance: luminance.face,
    backgroundLuminance: luminance.background,
    cameraRoll: state.roll,
    cameraMotion: motion,
  };
}

async function detectPerson(frame) {
  if (!state.model || video.readyState < 2) return null;
  const predictions = await state.model.detect(video, 3);
  const person = predictions
    .filter((item) => item.class === "person" && item.score > 0.45)
    .sort((a, b) => b.score - a.score)[0];

  if (!person) return null;
  const [x, y, width, height] = person.bbox;
  const fitted = fitVideoBoxToStage(frame);
  return {
    x: clamp((fitted.x + x * fitted.scaleX) / frame.width, 0, 1),
    y: clamp((fitted.y + y * fitted.scaleY) / frame.height, 0, 1),
    width: clamp((width * fitted.scaleX) / frame.width, 0, 1),
    height: clamp((height * fitted.scaleY) / frame.height, 0, 1),
    confidence: person.score,
    source: "coco-ssd",
  };
}

function getManualBoxMeasurement(frame) {
  const stage = overlayCanvas.getBoundingClientRect();
  const box = manualBox.getBoundingClientRect();
  return {
    x: clamp((box.left - stage.left) / frame.width, 0, 1),
    y: clamp((box.top - stage.top) / frame.height, 0, 1),
    width: clamp(box.width / frame.width, 0, 1),
    height: clamp(box.height / frame.height, 0, 1),
    confidence: 1,
    source: "demo",
  };
}

function estimateFaceBox(personBox) {
  if (!personBox) return null;
  return {
    x: personBox.x + personBox.width * 0.31,
    y: personBox.y + personBox.height * 0.04,
    width: personBox.width * 0.38,
    height: personBox.height * 0.16,
    confidence: personBox.confidence * 0.55,
    source: "estimated",
  };
}

function sampleLuminance(personBox) {
  if (!video.videoWidth || !video.videoHeight) {
    return { face: null, background: null };
  }

  const context = analysisCanvas.getContext("2d", { willReadFrequently: true });
  analysisCanvas.width = 160;
  analysisCanvas.height = 120;
  context.drawImage(video, 0, 0, analysisCanvas.width, analysisCanvas.height);

  const image = context.getImageData(0, 0, analysisCanvas.width, analysisCanvas.height);
  const background = averageLuminance(image.data);
  if (!personBox) return { face: null, background };

  const face = estimateFaceBox(personBox);
  const x = Math.floor(face.x * analysisCanvas.width);
  const y = Math.floor(face.y * analysisCanvas.height);
  const width = Math.max(4, Math.floor(face.width * analysisCanvas.width));
  const height = Math.max(4, Math.floor(face.height * analysisCanvas.height));
  const faceData = context.getImageData(x, y, width, height);
  return { face: averageLuminance(faceData.data), background };
}

function averageLuminance(data) {
  let total = 0;
  for (let index = 0; index < data.length; index += 4) {
    total += 0.2126 * data[index] + 0.7152 * data[index + 1] + 0.0722 * data[index + 2];
  }
  return Math.round(total / (data.length / 4));
}

function findIssues(measurements) {
  const issues = [];
  const box = measurements.personBox;

  if (!box) {
    issues.push(issue("subject_missing", 100, 0.92, "Photographer", "Frame the person", "danger"));
    return issues;
  }

  const area = box.width * box.height;
  const headroom = box.y;
  const bottom = box.y + box.height;
  const left = box.x;
  const right = box.x + box.width;

  if (area > thresholds.tooCloseArea) {
    issues.push(issue("subject_too_close", 82, box.confidence, "Photographer", "Step back", "warning"));
  }

  if (area < thresholds.tooFarArea) {
    issues.push(issue("subject_too_far", 76, box.confidence, "Photographer", "Step closer", "warning"));
  }

  if (headroom > thresholds.tooMuchHeadroom && area > thresholds.tooFarArea) {
    issues.push(issue("headroom_too_large", 62, box.confidence, "Photographer", "Raise camera", "warning"));
  }

  if (headroom < thresholds.tooLittleHeadroom) {
    issues.push(issue("headroom_too_small", 70, box.confidence, "Photographer", "Lower camera", "warning"));
  }

  if (bottom > 1 - thresholds.edgePad && area < thresholds.tooCloseArea) {
    issues.push(issue("feet_cropped", 88, box.confidence, "Photographer", "Keep feet in frame", "danger"));
  }

  if (left < thresholds.edgePad) {
    issues.push(issue("left_edge_cropped", 72, box.confidence, "Photographer", "Move right", "warning"));
  }

  if (right > 1 - thresholds.edgePad) {
    issues.push(issue("right_edge_cropped", 72, box.confidence, "Photographer", "Move left", "warning"));
  }

  if (Math.abs(measurements.cameraRoll) > thresholds.rollDegrees) {
    const instruction = measurements.cameraRoll > 0 ? "Tilt left" : "Tilt right";
    issues.push(issue("camera_tilted", 64, 0.7, "Photographer", instruction, "warning"));
  }

  if (
    typeof measurements.faceLuminance === "number" &&
    typeof measurements.backgroundLuminance === "number" &&
    measurements.faceLuminance < thresholds.darkFace &&
    measurements.backgroundLuminance - measurements.faceLuminance > thresholds.backlitDelta
  ) {
    issues.push(issue("subject_backlit", 58, 0.7, "Subject", "Face the light", "warning"));
  }

  if (area > 0.33 && box.height > 0.72) {
    issues.push(issue("scene_excluded", 50, box.confidence, "Photographer", "Include more view", "warning"));
  }

  return issues.sort((a, b) => b.priority - a.priority || b.severity - a.severity);
}

function issue(type, severity, confidence, recipient, instruction, tone) {
  return {
    type,
    severity,
    confidence: round(confidence),
    priority: severity * confidence,
    recipient,
    instruction,
    tone,
  };
}

function selectInstruction(issues, now) {
  const topIssue = issues.find((item) => item.confidence > 0.45);
  const key = topIssue ? topIssue.type : "ready";

  if (state.stableIssueKey !== key) {
    state.stableIssueKey = key;
    state.stableSince = now;
  }

  const stableFor = now - state.stableSince;
  const oldEnough = now - state.lastInstructionAt > thresholds.minInstructionMs;
  const repeatedTooSoon =
    state.lastInstruction &&
    state.lastInstruction.type === key &&
    now - state.lastInstructionAt < thresholds.repeatCooldownMs;

  if (stableFor < (topIssue ? thresholds.minIssueMs : thresholds.minReadyMs)) {
    return state.lastInstruction || { type: "waiting", recipient: "Camera", instruction: "Hold steady", tone: "waiting" };
  }

  if (!topIssue) {
    const ready = { type: "ready", recipient: "Camera", instruction: "Great shot", tone: "ready" };
    if (oldEnough || state.lastInstruction?.type !== "ready") commitInstruction(ready, now);
    return ready;
  }

  if (repeatedTooSoon && state.lastInstruction) return state.lastInstruction;
  if (!oldEnough && state.lastInstruction) return state.lastInstruction;

  commitInstruction(topIssue, now);
  return topIssue;
}

function commitInstruction(instruction, now) {
  state.lastInstruction = instruction;
  state.lastInstructionAt = now;
}

function drawOverlay(measurements, issues, selected) {
  const context = overlayCanvas.getContext("2d");
  const width = overlayCanvas.width;
  const height = overlayCanvas.height;
  context.clearRect(0, 0, width, height);

  context.strokeStyle = "rgba(255,255,255,0.2)";
  context.lineWidth = 1;
  context.beginPath();
  context.moveTo(width / 3, 0);
  context.lineTo(width / 3, height);
  context.moveTo((width * 2) / 3, 0);
  context.lineTo((width * 2) / 3, height);
  context.moveTo(0, height / 3);
  context.lineTo(width, height / 3);
  context.moveTo(0, (height * 2) / 3);
  context.lineTo(width, (height * 2) / 3);
  context.stroke();

  if (measurements.personBox) {
    drawBox(context, measurements.personBox, width, height, "#4dd0b3", "person");
  }
  if (measurements.faceBox) {
    drawBox(context, measurements.faceBox, width, height, "#f5c05a", "face");
  }

  if (selected && selected.type !== "ready") {
    drawDirectionHint(context, selected.instruction, width, height);
  }

  if (state.debug) {
    context.fillStyle = "rgba(0,0,0,0.58)";
    context.fillRect(14, height - 92, 260, 70);
    context.fillStyle = "#f7f3ea";
    context.font = "13px ui-monospace, SFMono-Regular, Menlo, monospace";
    context.fillText(`model: ${measurements.modelStatus}`, 26, height - 66);
    context.fillText(`roll: ${measurements.cameraRoll.toFixed(1)} deg`, 26, height - 44);
    context.fillText(`issues: ${issues.length}`, 26, height - 22);
  }
}

function drawBox(context, box, width, height, color, label) {
  const x = box.x * width;
  const y = box.y * height;
  const boxWidth = box.width * width;
  const boxHeight = box.height * height;
  context.strokeStyle = color;
  context.lineWidth = 3;
  context.strokeRect(x, y, boxWidth, boxHeight);
  context.fillStyle = color;
  context.font = "12px ui-sans-serif, system-ui";
  context.fillText(`${label} ${Math.round(box.confidence * 100)}%`, x + 6, Math.max(18, y - 8));
}

function drawDirectionHint(context, instruction, width, height) {
  context.save();
  context.fillStyle = "rgba(77,208,179,0.92)";
  context.font = "bold 42px ui-sans-serif, system-ui";
  context.textAlign = "center";
  context.textBaseline = "middle";
  const lower = instruction.toLowerCase();
  const arrow =
    lower.includes("left") ? "<-" :
    lower.includes("right") ? "->" :
    lower.includes("raise") ? "^" :
    lower.includes("lower") ? "v" :
    "";
  if (arrow) context.fillText(arrow, width / 2, height / 2);
  context.restore();
}

function setAdvice(recipient, text, tone) {
  recipientText.textContent = recipient;
  adviceText.textContent = text;
  adviceCard.dataset.tone = tone;
}

function renderDebug(measurements, issues) {
  if (!state.debug) return;
  measurementOutput.textContent = JSON.stringify(
    {
      modelStatus: measurements.modelStatus,
      personBox: measurements.personBox,
      faceBox: measurements.faceBox,
      faceLuminance: measurements.faceLuminance,
      backgroundLuminance: measurements.backgroundLuminance,
      cameraRoll: round(measurements.cameraRoll),
    },
    null,
    2
  );
  issueOutput.textContent = JSON.stringify(issues, null, 2);
}

function resizeCanvases() {
  const rect = overlayCanvas.getBoundingClientRect();
  const scale = window.devicePixelRatio || 1;
  const width = Math.max(1, Math.floor(rect.width * scale));
  const height = Math.max(1, Math.floor(rect.height * scale));
  if (overlayCanvas.width !== width || overlayCanvas.height !== height) {
    overlayCanvas.width = width;
    overlayCanvas.height = height;
  }
}

function getFrameRect() {
  const rect = overlayCanvas.getBoundingClientRect();
  return { width: rect.width, height: rect.height };
}

function fitVideoBoxToStage(frame) {
  const videoRatio = video.videoWidth / video.videoHeight;
  const stageRatio = frame.width / frame.height;
  let renderWidth = frame.width;
  let renderHeight = frame.height;
  let x = 0;
  let y = 0;

  if (videoRatio > stageRatio) {
    renderHeight = frame.height;
    renderWidth = frame.height * videoRatio;
    x = (frame.width - renderWidth) / 2;
  } else {
    renderWidth = frame.width;
    renderHeight = frame.width / videoRatio;
    y = (frame.height - renderHeight) / 2;
  }

  return {
    x,
    y,
    scaleX: renderWidth / video.videoWidth,
    scaleY: renderHeight / video.videoHeight,
  };
}

function makeManualBoxDraggable() {
  let drag = null;
  manualBox.addEventListener("pointerdown", (event) => {
    manualBox.setPointerCapture(event.pointerId);
    const rect = manualBox.getBoundingClientRect();
    drag = {
      startX: event.clientX,
      startY: event.clientY,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      resize: event.target.classList.contains("handle") ? event.target.classList[1] : null,
    };
  });

  manualBox.addEventListener("pointermove", (event) => {
    if (!drag) return;
    const stage = overlayCanvas.getBoundingClientRect();
    const dx = event.clientX - drag.startX;
    const dy = event.clientY - drag.startY;
    let left = drag.left - stage.left;
    let top = drag.top - stage.top;
    let width = drag.width;
    let height = drag.height;

    if (!drag.resize) {
      left += dx;
      top += dy;
    } else {
      if (drag.resize.includes("e")) width += dx;
      if (drag.resize.includes("s")) height += dy;
      if (drag.resize.includes("w")) {
        left += dx;
        width -= dx;
      }
      if (drag.resize.includes("n")) {
        top += dy;
        height -= dy;
      }
    }

    width = clamp(width, 48, stage.width);
    height = clamp(height, 70, stage.height);
    left = clamp(left, 0, stage.width - width);
    top = clamp(top, 0, stage.height - height);
    manualBox.style.left = `${left}px`;
    manualBox.style.top = `${top}px`;
    manualBox.style.width = `${width}px`;
    manualBox.style.height = `${height}px`;
  });

  manualBox.addEventListener("pointerup", () => {
    drag = null;
  });
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function round(value) {
  return typeof value === "number" ? Math.round(value * 1000) / 1000 : value;
}
