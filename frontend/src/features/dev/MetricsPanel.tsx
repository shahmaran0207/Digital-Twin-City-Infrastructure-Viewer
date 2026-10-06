import { useState } from 'react';

const box: React.CSSProperties = {
  position: 'absolute',
  right: 12,
  bottom: 32,
  zIndex: 10,
  minWidth: 190,
  padding: '8px 10px',
  background: 'rgba(20,20,24,0.85)',
  color: '#ccd',
  borderRadius: 6,
  font: '11px/1.5 ui-monospace, monospace',
  backdropFilter: 'blur(4px)',
};

const row: React.CSSProperties = { display: 'flex', justifyContent: 'space-between', gap: 10 };

export interface Metrics {
  fetchMs: number;
  parseMs: number;
  bytes: number;
  buildMs: number | null;
  entityCount: number | null;
  fps: number;
  minFps: number;
}

/**
 * 개발용 계측 패널 — 제품 UI가 아니다.
 *
 * {@code import.meta.env.DEV} 일 때만 렌더하므로 배포 빌드에는 나오지 않는다.
 * 격자 1만 개를 Cesium이 버티는지 판단하려고 만들었다. 콘솔에만 찍으면
 * 지도를 조작하면서 FPS가 어떻게 변하는지 볼 수 없어 화면에 띄운다.
 */
export function MetricsPanel({ metrics }: { metrics: Metrics | null }) {
  const [open, setOpen] = useState(true);

  if (!import.meta.env.DEV) return null;

  return (
    <div style={box}>
      <div
        style={{ ...row, cursor: 'pointer', color: '#9aa' }}
        onClick={() => setOpen((previous) => !previous)}
      >
        <span>계측 (dev)</span>
        <span>{open ? '−' : '+'}</span>
      </div>

      {open && metrics && (
        <div style={{ marginTop: 6 }}>
          <div style={row}>
            <span>전송</span>
            <span>{Math.round(metrics.fetchMs)} ms</span>
          </div>
          <div style={row}>
            <span>JSON 파싱</span>
            <span>{Math.round(metrics.parseMs)} ms</span>
          </div>
          <div style={row}>
            <span>원본</span>
            <span>{(metrics.bytes / 1024 / 1024).toFixed(2)} MB</span>
          </div>
          <div style={row}>
            <span>엔티티 생성</span>
            <span>{metrics.buildMs === null ? '…' : `${Math.round(metrics.buildMs)} ms`}</span>
          </div>
          <div style={row}>
            <span>엔티티 수</span>
            <span>{metrics.entityCount?.toLocaleString() ?? '…'}</span>
          </div>
          <div style={row}>
            <span>FPS 현재/최저</span>
            <strong
              style={{
                color: metrics.fps >= 50 ? '#30a46c' : metrics.fps >= 25 ? '#f5a623' : '#e5484d',
              }}
            >
              {metrics.fps} / {metrics.minFps}
            </strong>
          </div>
        </div>
      )}

      {open && !metrics && <div style={{ marginTop: 6, color: '#889' }}>레이어 꺼짐</div>}
    </div>
  );
}
