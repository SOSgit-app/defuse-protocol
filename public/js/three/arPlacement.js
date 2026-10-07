/**
 * AR plane snapping — hit-test / plane-detection reticle + place trigger.
 * Quest Browser: immersive-ar with plane-detection (+ hit-test when available).
 */
import * as THREE from 'three';

function planeNormalFromPose(matrix) {
  // Plane local +Y is the normal in plane space.
  return new THREE.Vector3(matrix[4], matrix[5], matrix[6]).normalize();
}

function hitTestPlanes(frame, origin, direction, referenceSpace) {
  const planes = frame.detectedPlanes;
  if (!planes || !planes.size) return null;

  let best = null;
  planes.forEach((plane) => {
    if (plane.orientation && plane.orientation !== 'horizontal') return;
    const pose = frame.getPose(plane.planeSpace, referenceSpace);
    if (!pose) return;
    const m = pose.transform.matrix;
    const normal = planeNormalFromPose(m);
    // Prefer upward-facing surfaces (tables / floors).
    if (normal.y < 0.55) return;

    const center = new THREE.Vector3(m[12], m[13], m[14]);
    const denom = direction.dot(normal);
    if (Math.abs(denom) < 1e-4) return;
    const t = center.clone().sub(origin).dot(normal) / denom;
    if (t < 0.05 || t > 4.5) return;

    const point = origin.clone().addScaledVector(direction, t);
    // Keep hit roughly inside the plane polygon if present.
    if (plane.polygon && plane.polygon.length >= 3) {
      const inv = new THREE.Matrix4().fromArray(m).invert();
      const local = point.clone().applyMatrix4(inv);
      if (!pointInPolygonXZ(local.x, local.z, plane.polygon)) return;
    }

    if (!best || t < best.distance) {
      best = { distance: t, point, normal, matrix: m };
    }
  });
  return best;
}

function pointInPolygonXZ(x, z, polygon) {
  // Ray cast in XZ; polygon points are DOMPoint-like in plane space (y≈0).
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].x;
    const zi = polygon[i].z;
    const xj = polygon[j].x;
    const zj = polygon[j].z;
    const intersect = ((zi > z) !== (zj > z))
      && (x < ((xj - xi) * (z - zi)) / ((zj - zi) || 1e-9) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/**
 * @param {{ renderer: THREE.WebGLRenderer, scene: THREE.Scene, stage: THREE.Group }} opts
 */
export function createArPlacement({ renderer, scene, stage }) {
  const reticle = new THREE.Mesh(
    new THREE.RingGeometry(0.08, 0.11, 32).rotateX(-Math.PI / 2),
    new THREE.MeshBasicMaterial({
      color: 0x39d98a,
      transparent: true,
      opacity: 0.9,
      side: THREE.DoubleSide,
      depthWrite: false
    })
  );
  reticle.visible = false;
  reticle.renderOrder = 20;
  scene.add(reticle);

  const hint = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: makeHintTexture('AIM AT TABLE · TRIGGER TO PLACE'),
      transparent: true,
      depthTest: false
    })
  );
  hint.scale.set(0.55, 0.08, 1);
  hint.visible = false;
  hint.renderOrder = 21;
  scene.add(hint);

  let active = false;
  let placed = false;
  let hitTestSource = null;
  let hitTestRequested = false;
  let roomCaptureTried = false;
  let sessionStartedAt = 0;
  let lastHit = null;
  const _origin = new THREE.Vector3();
  const _dir = new THREE.Vector3();
  const _mat = new THREE.Matrix4();
  const _pos = new THREE.Vector3();
  const _quat = new THREE.Quaternion();
  const _scale = new THREE.Vector3();
  const _euler = new THREE.Euler();

  function resetStageHome() {
    stage.position.set(0, 0, 0);
    stage.rotation.set(0, 0, 0);
    stage.visible = true;
  }

  function begin() {
    active = true;
    placed = false;
    hitTestSource = null;
    hitTestRequested = false;
    roomCaptureTried = false;
    sessionStartedAt = performance.now();
    lastHit = null;
    reticle.visible = false;
    hint.visible = true;
    // Preview follows reticle; start slightly in front until first hit.
    stage.visible = true;
    stage.position.set(0, 0, -0.9);
    stage.rotation.set(0, 0, 0);
  }

  function end() {
    active = false;
    placed = false;
    hitTestSource = null;
    hitTestRequested = false;
    reticle.visible = false;
    hint.visible = false;
    lastHit = null;
    resetStageHome();
  }

  function unlock() {
    if (!active) return;
    placed = false;
    reticle.visible = !!lastHit;
    hint.visible = true;
    hint.material.map = makeHintTexture('AIM AT TABLE · TRIGGER TO PLACE');
    hint.material.map.needsUpdate = true;
  }

  function isPlacing() {
    return active && !placed;
  }

  function isPlaced() {
    return !active || placed;
  }

  function ensureHitTest(session) {
    if (hitTestRequested || !session || !session.requestHitTestSource) return;
    hitTestRequested = true;
    session.requestReferenceSpace('viewer').then((viewerSpace) => {
      session.requestHitTestSource({ space: viewerSpace }).then((source) => {
        hitTestSource = source;
      }).catch(() => {
        hitTestSource = null;
      });
    }).catch(() => {
      hitTestSource = null;
    });
    session.addEventListener('end', () => {
      hitTestSource = null;
      hitTestRequested = false;
    });
  }

  function maybeRoomCapture(session, frame) {
    if (roomCaptureTried || !session) return;
    const elapsed = performance.now() - sessionStartedAt;
    if (elapsed < 2500) return;
    const planes = frame?.detectedPlanes;
    const hasPlanes = planes && planes.size > 0;
    if (hasPlanes) return;
    roomCaptureTried = true;
    if (typeof session.initiateRoomCapture === 'function') {
      session.initiateRoomCapture().catch(() => {});
    }
  }

  function applyPose(position, quaternion) {
    // Table surface is local y=0 on the stage; sit that on the hit plane.
    stage.position.copy(position);
    if (quaternion) {
      _euler.setFromQuaternion(quaternion, 'YXZ');
      stage.rotation.set(0, _euler.y, 0);
    }
  }

  function tick(frame) {
    if (!active || placed) {
      reticle.visible = false;
      hint.visible = false;
      return;
    }
    if (!frame) return;

    const session = renderer.xr.getSession();
    const referenceSpace = renderer.xr.getReferenceSpace();
    if (!session || !referenceSpace) return;

    ensureHitTest(session);
    maybeRoomCapture(session, frame);

    lastHit = null;

    // 1) Preferred: WebXR hit-test results
    if (hitTestSource) {
      const results = frame.getHitTestResults(hitTestSource);
      if (results.length) {
        const pose = results[0].getPose(referenceSpace);
        if (pose) {
          _mat.fromArray(pose.transform.matrix);
          _mat.decompose(_pos, _quat, _scale);
          // Prefer roughly horizontal hits (table / floor).
          const up = new THREE.Vector3(0, 1, 0).applyQuaternion(_quat);
          if (up.y > 0.55) {
            lastHit = { position: _pos.clone(), quaternion: _quat.clone() };
          }
        }
      }
    }

    // 2) Fallback: ray from right/left controller against detected planes
    if (!lastHit && frame.detectedPlanes) {
      for (const src of session.inputSources) {
        if (!src.targetRaySpace) continue;
        const pose = frame.getPose(src.targetRaySpace, referenceSpace);
        if (!pose) continue;
        _mat.fromArray(pose.transform.matrix);
        _origin.setFromMatrixPosition(_mat);
        _dir.set(0, 0, -1).transformDirection(_mat);
        const hit = hitTestPlanes(frame, _origin, _dir, referenceSpace);
        if (hit && (!lastHit || hit.distance < lastHit.distance)) {
          lastHit = {
            position: hit.point.clone(),
            quaternion: new THREE.Quaternion().setFromUnitVectors(
              new THREE.Vector3(0, 1, 0),
              hit.normal
            ),
            distance: hit.distance
          };
        }
      }
    }

    if (lastHit) {
      reticle.visible = true;
      reticle.position.copy(lastHit.position);
      reticle.position.y += 0.002;
      applyPose(lastHit.position, lastHit.quaternion);
      stage.visible = true;
      hint.position.copy(lastHit.position);
      hint.position.y += 0.18;
      hint.visible = true;
    } else {
      reticle.visible = false;
      hint.visible = true;
      const cam = renderer.xr.getCamera();
      cam.getWorldPosition(_origin);
      cam.getWorldDirection(_dir);
      hint.position.copy(_origin).addScaledVector(_dir, 1.1);
      hint.position.y += 0.05;
    }
  }

  function tryPlace() {
    if (!active || placed || !lastHit) return false;
    applyPose(lastHit.position, lastHit.quaternion);
    placed = true;
    reticle.visible = false;
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
    resetStageHome
  };
}

function makeHintTexture(text) {
  const c = document.createElement('canvas');
  c.width = 1024;
  c.height = 128;
  const ctx = c.getContext('2d');
  ctx.clearRect(0, 0, c.width, c.height);
  ctx.fillStyle = 'rgba(8, 12, 18, 0.72)';
  roundRect(ctx, 16, 16, c.width - 32, c.height - 32, 18);
  ctx.fill();
  ctx.fillStyle = '#9dffc4';
  ctx.font = "bold 44px Consolas, 'Courier New', monospace";
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
