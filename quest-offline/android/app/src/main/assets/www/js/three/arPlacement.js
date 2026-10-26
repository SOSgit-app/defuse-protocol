/**
 * Bomb/table placement + free transform.
 * - AR setup: sticks + dual grips until TRIGGER LOCK (timer paused).
 * - Anytime in VR/AR: hold BOTH grips to move / twist / resize (game keeps running).
 */
import * as THREE from 'three';

const MOVE_SPEED = 1.35;
const HEIGHT_SPEED = 0.9;
const YAW_SPEED = 1.8;
const SCALE_SPEED = 0.9;
const DEADZONE = 0.18;
const SCALE_MIN = 0.55;
const SCALE_MAX = 1.65;
const HEIGHT_MIN = 0.12;
const HEIGHT_MAX = 1.55;
const GRIP_HOLD = 0.55;
const HINT_IDLE = 'TIMER PAUSED · BOTH GRIPS / STICKS · TRIGGER LOCK';
const HINT_HOLD = 'HOLDING — MOVE HANDS / SPREAD TO RESIZE · TRIGGER LOCK';
const HINT_FREE = 'BOTH GRIPS — MOVE / TURN / RESIZE';

function readAxes(gamepad) {
  if (!gamepad || !gamepad.axes) return { x: 0, y: 0 };
  const ax = gamepad.axes;
  if (ax.length >= 4) return { x: ax[2], y: ax[3] };
  return { x: ax[0] || 0, y: ax[1] || 0 };
}

function axis(v) {
  return Math.abs(v) > DEADZONE ? v : 0;
}

function squeezeValue(src) {
  const b = src.gamepad?.buttons?.[1];
  if (!b) return 0;
  return b.value || (b.pressed ? 1 : 0);
}

/**
 * @param {{ renderer: THREE.WebGLRenderer, scene: THREE.Scene, stage: THREE.Group }} opts
 */
export function createArPlacement({ renderer, scene, stage }) {
  const hint = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: makeHintTexture(HINT_IDLE),
      transparent: true,
      depthTest: false
    })
  );
  hint.scale.set(0.78, 0.09, 1);
  hint.visible = false;
  hint.renderOrder = 21;
  scene.add(hint);

  let active = false;
  let placed = false;
  let stageScale = 1;
  let defaultHeight = 0.75;
  let yawOffset = 0;
  let menuBlocked = false;
  /** @type {null | {
   *   mid: THREE.Vector3, dist: number, yaw: number,
   *   stagePos: THREE.Vector3, stageScale: number, stageYaw: number
   * }} */
  let dualHold = null;

  const _fwd = new THREE.Vector3();
  const _right = new THREE.Vector3();
  const _camPos = new THREE.Vector3();
  const _toCam = new THREE.Vector3();
  const _leftPos = new THREE.Vector3();
  const _rightPos = new THREE.Vector3();
  const _mid = new THREE.Vector3();
  const _delta = new THREE.Vector3();

  function applyScale() {
    stage.scale.setScalar(stageScale);
  }

  /** Bomb serial / front is +Z — yaw so that face points at the player. */
  function facePlayerYaw() {
    const cam = renderer.xr.getCamera();
    cam.getWorldPosition(_camPos);
    _toCam.set(_camPos.x - stage.position.x, 0, _camPos.z - stage.position.z);
    if (_toCam.lengthSq() < 1e-6) return stage.rotation.y;
    return Math.atan2(_toCam.x, _toCam.z);
  }

  function applyFacing() {
    stage.rotation.y = facePlayerYaw() + yawOffset;
  }

  function setDefaultHeight(m) {
    const next = Math.max(HEIGHT_MIN, Math.min(HEIGHT_MAX, Number(m) || 0.75));
    const prev = defaultHeight;
    defaultHeight = next;
    if (active) stage.position.y += next - prev;
  }

  function resetStageHome() {
    stage.position.set(0, defaultHeight, 0);
    stage.rotation.set(0, 0, 0);
    stageScale = 1;
    yawOffset = 0;
    dualHold = null;
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
    yawOffset = 0;
    applyFacing();
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

  /** AR: spawn in front, require TRIGGER LOCK before the clock runs. */
  function begin() {
    active = true;
    placed = false;
    yawOffset = 0;
    dualHold = null;
    spawnInFront();
    setHint(HINT_IDLE);
    hint.visible = true;
  }

  /**
   * VR (or post-lock): grips work anytime; sticks do not steal locomotion.
   * Keeps current stage pose if already set.
   */
  function attachSession() {
    active = true;
    placed = true;
    dualHold = null;
    hint.visible = false;
    if (stage.position.lengthSq() < 1e-8) {
      stage.position.set(0, defaultHeight, 0);
    }
    stageScale = stage.scale.x || 1;
    applyScale();
  }

  function end() {
    active = false;
    placed = false;
    dualHold = null;
    menuBlocked = false;
    hint.visible = false;
    resetStageHome();
  }

  function unlock() {
    if (!active) return;
    placed = false;
    yawOffset = 0;
    dualHold = null;
    applyFacing();
    setHint(HINT_IDLE);
    hint.visible = true;
  }

  function setMenuBlocked(on) {
    menuBlocked = !!on;
    if (menuBlocked && dualHold) {
      yawOffset = stage.rotation.y - facePlayerYaw();
      dualHold = null;
    }
  }

  function isPlacing() {
    return active && !placed;
  }

  function isPlaced() {
    return !active || placed;
  }

  function isGrabbing() {
    return !!dualHold;
  }

  function gripWorldPos(handedness, out) {
    for (let i = 0; i < 2; i++) {
      const g = renderer.xr.getControllerGrip(i);
      const src = g?.userData?.inputSource;
      if (src && src.handedness === handedness) {
        g.updateWorldMatrix(true, false);
        g.getWorldPosition(out);
        return true;
      }
    }
    return false;
  }

  function handYaw(left, right) {
    return Math.atan2(right.x - left.x, right.z - left.z);
  }

  function releaseDualHold() {
    if (!dualHold) return;
    yawOffset = stage.rotation.y - facePlayerYaw();
    dualHold = null;
    if (!placed) setHint(HINT_IDLE);
  }

  function tick(dt) {
    if (!active) {
      hint.visible = false;
      return;
    }

    hint.position.copy(stage.position);
    hint.position.y += 0.28 * stageScale;

    const session = renderer.xr.getSession();
    if (!session || menuBlocked) {
      if (dualHold) releaseDualHold();
      hint.visible = !placed;
      return;
    }

    let movePad = { x: 0, y: 0 };
    let lookPad = { x: 0, y: 0 };
    let grow = 0;
    let shrink = 0;
    let leftSqueeze = 0;
    let rightSqueeze = 0;

    for (const src of session.inputSources) {
      if (!src.gamepad) continue;
      const axes = readAxes(src.gamepad);
      if (src.handedness === 'left') movePad = axes;
      if (src.handedness === 'right') lookPad = axes;
      const v = squeezeValue(src);
      if (src.handedness === 'right') {
        grow = Math.max(grow, v);
        rightSqueeze = v;
      }
      if (src.handedness === 'left') {
        shrink = Math.max(shrink, v);
        leftSqueeze = v;
      }
    }

    const bothGrips =
      leftSqueeze >= GRIP_HOLD &&
      rightSqueeze >= GRIP_HOLD &&
      gripWorldPos('left', _leftPos) &&
      gripWorldPos('right', _rightPos);

    // Dual-grip grab works anytime (VR + AR, even after lock).
    if (bothGrips) {
      _mid.addVectors(_leftPos, _rightPos).multiplyScalar(0.5);
      const dist = Math.max(0.04, _leftPos.distanceTo(_rightPos));
      const yaw = handYaw(_leftPos, _rightPos);

      if (!dualHold) {
        dualHold = {
          mid: _mid.clone(),
          dist,
          yaw,
          stagePos: stage.position.clone(),
          stageScale,
          stageYaw: stage.rotation.y
        };
        setHint(placed ? HINT_FREE : HINT_HOLD);
      } else {
        _delta.subVectors(_mid, dualHold.mid);
        stage.position.copy(dualHold.stagePos).add(_delta);
        stage.position.y = THREE.MathUtils.clamp(stage.position.y, HEIGHT_MIN, HEIGHT_MAX);

        const scaleMul = dist / dualHold.dist;
        stageScale = THREE.MathUtils.clamp(
          dualHold.stageScale * scaleMul,
          SCALE_MIN,
          SCALE_MAX
        );
        applyScale();
        stage.rotation.y = dualHold.stageYaw + (yaw - dualHold.yaw);
      }
      hint.visible = true;
      return;
    }

    if (dualHold) releaseDualHold();

    // Stick / single-grip controls only during AR setup (before lock).
    if (placed) {
      hint.visible = false;
      return;
    }

    hint.visible = true;
    const cam = renderer.xr.getCamera();
    cam.getWorldDirection(_fwd);
    _fwd.y = 0;
    if (_fwd.lengthSq() < 1e-6) _fwd.set(0, 0, -1);
    else _fwd.normalize();
    _right.crossVectors(_fwd, new THREE.Vector3(0, 1, 0)).normalize();

    const mx = axis(movePad.x);
    const my = axis(movePad.y);
    if (mx || my) {
      stage.position.addScaledVector(_fwd, my * MOVE_SPEED * dt);
      stage.position.addScaledVector(_right, mx * MOVE_SPEED * dt);
    }

    const yaw = axis(lookPad.x);
    const hy = axis(lookPad.y);
    if (yaw) yawOffset += yaw * YAW_SPEED * dt;
    if (hy) {
      stage.position.y = THREE.MathUtils.clamp(
        stage.position.y + hy * HEIGHT_SPEED * dt,
        HEIGHT_MIN,
        HEIGHT_MAX
      );
    }

    applyFacing();

    if (grow > 0.08) stageScale += grow * SCALE_SPEED * dt;
    if (shrink > 0.08) stageScale -= shrink * SCALE_SPEED * dt;
    stageScale = THREE.MathUtils.clamp(stageScale, SCALE_MIN, SCALE_MAX);
    applyScale();
  }

  function tryPlace() {
    if (!active || placed) return false;
    if (dualHold) releaseDualHold();
    placed = true;
    hint.visible = false;
    return true;
  }

  return {
    begin,
    attachSession,
    end,
    unlock,
    tick,
    tryPlace,
    isPlacing,
    isPlaced,
    isGrabbing,
    setMenuBlocked,
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
  ctx.font = "bold 36px Consolas, 'Courier New', monospace";
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
