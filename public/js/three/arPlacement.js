/**
 * AR manual placement — smooth move / height / turn / scale with sticks.
 * Trigger locks the stage until MOVE BOMB unlocks it again.
 */
import * as THREE from 'three';

const MOVE_SPEED = 1.35;
const HEIGHT_SPEED = 0.9;
const YAW_SPEED = 1.8;
const SCALE_SPEED = 0.9;
const DEADZONE = 0.18;
const SCALE_MIN = 0.55;
const SCALE_MAX = 1.65;

function readAxes(gamepad) {
  if (!gamepad || !gamepad.axes) return { x: 0, y: 0 };
  const ax = gamepad.axes;
  if (ax.length >= 4) return { x: ax[2], y: ax[3] };
  return { x: ax[0] || 0, y: ax[1] || 0 };
}

function axis(v) {
  return Math.abs(v) > DEADZONE ? v : 0;
}

/**
 * @param {{ renderer: THREE.WebGLRenderer, scene: THREE.Scene, stage: THREE.Group }} opts
 */
export function createArPlacement({ renderer, scene, stage }) {
  const hint = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: makeHintTexture('L MOVE · R TURN/HEIGHT · GRIP SIZE · TRIGGER LOCK'),
      transparent: true,
      depthTest: false
    })
  );
  hint.scale.set(0.72, 0.09, 1);
  hint.visible = false;
  hint.renderOrder = 21;
  scene.add(hint);

  let active = false;
  let placed = false;
  let stageScale = 1;
  let defaultHeight = 0.75;
  const _fwd = new THREE.Vector3();
  const _right = new THREE.Vector3();
  const _camPos = new THREE.Vector3();

  function applyScale() {
    stage.scale.setScalar(stageScale);
  }

  function setDefaultHeight(m) {
    const next = Math.max(0.35, Math.min(1.45, Number(m) || 0.75));
    const prev = defaultHeight;
    defaultHeight = next;
    // Keep the table's relative offset when the setting changes mid-session.
    if (active) stage.position.y += next - prev;
  }

  function resetStageHome() {
    stage.position.set(0, defaultHeight, 0);
    stage.rotation.set(0, 0, 0);
    stageScale = 1;
    applyScale();
    stage.visible = true;
  }

  function spawnInFront() {
    const cam = renderer.xr.getCamera();
    cam.getWorldPosition(_camPos);
    cam.getWorldDirection(_fwd);
    _fwd.y = 0;
    if (_fwd.lengthSq() < 1e-6) _fwd.set(0, 0, -1);
    else _fwd.normalize();
    stage.position.set(
      _camPos.x + _fwd.x * 1.05,
      defaultHeight,
      _camPos.z + _fwd.z * 1.05
    );
    stage.rotation.set(0, Math.atan2(_fwd.x, _fwd.z), 0);
    stageScale = 1;
    applyScale();
    stage.visible = true;
  }

  function setHint(text) {
    const map = makeHintTexture(text);
    if (hint.material.map) hint.material.map.dispose();
    hint.material.map = map;
    hint.material.needsUpdate = true;
  }

  function begin() {
    active = true;
    placed = false;
    spawnInFront();
    setHint('L MOVE · R TURN/HEIGHT · GRIP SIZE · TRIGGER LOCK');
    hint.visible = true;
  }

  function end() {
    active = false;
    placed = false;
    hint.visible = false;
    resetStageHome();
  }

  function unlock() {
    if (!active) return;
    placed = false;
    setHint('L MOVE · R TURN/HEIGHT · GRIP SIZE · TRIGGER LOCK');
    hint.visible = true;
  }

  function isPlacing() {
    return active && !placed;
  }

  function isPlaced() {
    return !active || placed;
  }

  function tick(dt) {
    if (!active) {
      hint.visible = false;
      return;
    }

    hint.position.copy(stage.position);
    hint.position.y += 0.28 * stageScale;

    if (placed) {
      hint.visible = false;
      return;
    }

    hint.visible = true;
    const session = renderer.xr.getSession();
    if (!session) return;

    let movePad = { x: 0, y: 0 };
    let lookPad = { x: 0, y: 0 };
    let grow = 0;
    let shrink = 0;

    for (const src of session.inputSources) {
      if (!src.gamepad) continue;
      const axes = readAxes(src.gamepad);
      if (src.handedness === 'left') movePad = axes;
      if (src.handedness === 'right') lookPad = axes;
      const squeeze = src.gamepad.buttons?.[1];
      const v = squeeze ? (squeeze.value || (squeeze.pressed ? 1 : 0)) : 0;
      if (src.handedness === 'right') grow = Math.max(grow, v);
      if (src.handedness === 'left') shrink = Math.max(shrink, v);
    }

    const cam = renderer.xr.getCamera();
    cam.getWorldDirection(_fwd);
    _fwd.y = 0;
    if (_fwd.lengthSq() < 1e-6) _fwd.set(0, 0, -1);
    else _fwd.normalize();
    _right.crossVectors(_fwd, new THREE.Vector3(0, 1, 0)).normalize();

    const mx = axis(movePad.x);
    const my = axis(movePad.y);
    if (mx || my) {
      // Stick forward = push table away (same sense as walk stick).
      stage.position.addScaledVector(_fwd, -my * MOVE_SPEED * dt);
      stage.position.addScaledVector(_right, mx * MOVE_SPEED * dt);
    }

    const yaw = axis(lookPad.x);
    const hy = axis(lookPad.y);
    if (yaw) stage.rotation.y -= yaw * YAW_SPEED * dt;
    if (hy) {
      stage.position.y = THREE.MathUtils.clamp(
        stage.position.y - hy * HEIGHT_SPEED * dt,
        Math.max(0.35, defaultHeight - 0.45),
        Math.min(1.45, defaultHeight + 0.45)
      );
    }

    // Right grip = bigger, left grip = smaller
    if (grow > 0.08) stageScale += grow * SCALE_SPEED * dt;
    if (shrink > 0.08) stageScale -= shrink * SCALE_SPEED * dt;
    stageScale = THREE.MathUtils.clamp(stageScale, SCALE_MIN, SCALE_MAX);
    applyScale();
  }

  function tryPlace() {
    if (!active || placed) return false;
    placed = true;
    hint.visible = false;
    return true;
  }

  return {
    begin,
    end,
    unlock,
    tick,
    tryPlace,
    isPlacing,
    isPlaced,
    resetStageHome,
    setDefaultHeight
  };
}

function makeHintTexture(text) {
  const c = document.createElement('canvas');
  c.width = 1280;
  c.height = 128;
  const ctx = c.getContext('2d');
  ctx.clearRect(0, 0, c.width, c.height);
  ctx.fillStyle = 'rgba(8, 12, 18, 0.75)';
  roundRect(ctx, 16, 16, c.width - 32, c.height - 32, 18);
  ctx.fill();
  ctx.fillStyle = '#9dffc4';
  ctx.font = "bold 40px Consolas, 'Courier New', monospace";
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, c.width / 2, c.height / 2 + 2);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
