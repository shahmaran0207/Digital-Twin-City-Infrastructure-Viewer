import type { ReactNode } from 'react';
import { LAYERS, LAYER_GROUP_LABEL, type LayerGroup, type LayerId } from './layers';

const panel: React.CSSProperties = {
  position: 'absolute',
  top: 12,
  left: 12,
  zIndex: 10,
  width: 300,
  maxHeight: 'calc(100vh - 24px)',
  overflowY: 'auto',
  padding: '12px 14px',
  background: 'rgba(20,20,24,0.88)',
  color: '#eee',
  borderRadius: 8,
  font: '12px/1.5 system-ui, sans-serif',
  backdropFilter: 'blur(4px)',
};

const groupTitle: React.CSSProperties = {
  margin: '14px 0 6px',
  fontSize: 11,
  letterSpacing: '0.04em',
  color: '#9aa',
  textTransform: 'uppercase',
};

const GROUPS: LayerGroup[] = ['core', 'extension'];

interface Props {
  activeLayers: Set<LayerId>;
  onToggleLayer: (id: LayerId) => void;
  /** 켜진 레이어가 자기 세부 컨트롤(범례·필터·상세)을 여기에 끼운다 */
  children?: ReactNode;
}

/**
 * 좌측 레이어 패널 — 이 앱의 뼈대 UI.
 *
 * 레이어별 세부 컨트롤은 여기서 직접 그리지 않고 {@link Props.children}으로 받는다.
 * 패널이 레이어의 내용을 알게 되면 레이어가 늘 때마다 이 파일이 비대해진다.
 */
export function LayerPanel({ activeLayers, onToggleLayer, children }: Props) {
  return (
    <div style={panel}>
      <div style={{ fontSize: 14, fontWeight: 600 }}>부산 디지털트윈 인프라 뷰어</div>
      <div style={{ color: '#9aa', marginTop: 2 }}>시설물·인프라 3D 시각화 · 부산 한정</div>

      {GROUPS.map((group) => (
        <div key={group}>
          <div style={groupTitle}>{LAYER_GROUP_LABEL[group]}</div>
          {LAYERS.filter((layer) => layer.group === group).map((layer) => {
            const ready = layer.status === 'ready';
            return (
              <label
                key={layer.id}
                title={layer.phase}
                style={{
                  display: 'block',
                  padding: '3px 0',
                  cursor: ready ? 'pointer' : 'not-allowed',
                  opacity: ready ? 1 : 0.45,
                }}
              >
                <input
                  type="checkbox"
                  disabled={!ready}
                  checked={activeLayers.has(layer.id)}
                  onChange={() => onToggleLayer(layer.id)}
                  style={{ marginRight: 6 }}
                />
                {layer.name}
                {!ready && <span style={{ color: '#889', marginLeft: 6 }}>준비 중</span>}
                <div style={{ color: '#889', fontSize: 11, marginLeft: 20 }}>{layer.summary}</div>
              </label>
            );
          })}
        </div>
      ))}

      {children}
    </div>
  );
}
