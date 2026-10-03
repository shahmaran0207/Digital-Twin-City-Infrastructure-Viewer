import { Viewer, CameraFlyTo } from "resium";
import { useCallback, useEffect, useRef, useState } from "react";
import { checkBackend } from "./api/test";
import type { CesiumComponentRef } from "resium";
import { Ion, Rectangle } from "cesium";
import type { Viewer as CesiumViewer } from "cesium";
import { LayerPanel } from "./features/layers/LayerPanel";
import type { LayerId } from "./features/layers/layers";
import { MetricsPanel, type Metrics } from "./features/dev/MetricsPanel";
import { VulnerabilityControls } from "./features/vulnerability/VulnerabilityControls";
import {
  VulnerabilityGridLayer,
  type GridRenderStats,
} from "./features/vulnerability/VulnerabilityGridLayer";
import {
  loadVulnerabilityGrid,
  type Grade,
  type GridFeatureCollection,
  type GridMeta,
  type GridProps,
} from "./features/vulnerability/grid";
import { useFps } from "./features/vulnerability/useFps";

Ion.defaultAccessToken = import.meta.env.VITE_CESIUM_ION_TOKEN;

/**
 * 초기 화면 범위 — 부산.
 *
 * 고도(미터)를 찍지 않고 Rectangle을 주는 이유: Cesium이 창 비율에 맞춰 알아서 맞춘다.
 * 고도를 고정하면 세로로 긴 창에서는 잘리고 가로로 긴 창에서는 너무 멀어진다.
 * 범위는 부산 행정구역(대략 128.7~129.35E, 34.9~35.45N)에 여유를 둔 값이다.
 */
const BUSAN = Rectangle.fromDegrees(128.7, 34.88, 129.35, 35.45);

export default function App() {
  const viewerRef = useRef<CesiumComponentRef<CesiumViewer>>(null);

  // 기본 레이어(시설물·위기레벨)는 아직 미구현이라, 지금 켤 수 있는 것은 확장 레이어 하나뿐이다.
  const [activeLayers, setActiveLayers] = useState<Set<LayerId>>(
    new Set<LayerId>(["vulnerability"]),
  );

  const [grid, setGrid] = useState<GridFeatureCollection | null>(null);
  const [meta, setMeta] = useState<GridMeta | null>(null);
  const [loadMs, setLoadMs] = useState<{ fetchMs: number; parseMs: number; bytes: number } | null>(
    null,
  );
  const [renderStats, setRenderStats] = useState<GridRenderStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [picked, setPicked] = useState<{ gridId: number; props: GridProps } | null>(null);

  // 전체 13,439개를 처음부터 올리면 느릴 때 원인 분리가 어렵다.
  // G(9,407개)는 "나머지"라 정보량도 가장 낮아 기본에서 뺀다 — 체크박스로 켜서 비교할 수 있다.
  const [visibleGrades, setVisibleGrades] = useState<Set<Grade>>(new Set<Grade>(["R", "Y"]));

  const vulnerabilityOn = activeLayers.has("vulnerability");
  const { fps, minFps } = useFps();

  useEffect(() => {
    checkBackend().then(console.log).catch(console.error);
  }, []);

  // 레이어를 켤 때 처음 한 번만 받는다. 껐다 켜도 다시 내려받지 않는다.
  useEffect(() => {
    if (!vulnerabilityOn || grid) return;
    let cancelled = false;
    loadVulnerabilityGrid()
      .then((result) => {
        if (cancelled) return;
        setGrid(result.data);
        setMeta(result.meta);
        setLoadMs({ fetchMs: result.fetchMs, parseMs: result.parseMs, bytes: result.bytes });
      })
      .catch((cause: Error) => {
        if (!cancelled) setError(cause.message);
      });
    return () => {
      cancelled = true;
    };
  }, [vulnerabilityOn, grid]);

  const toggleLayer = useCallback((id: LayerId) => {
    setActiveLayers((previous) => {
      const next = new Set(previous);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const toggleGrade = useCallback((grade: Grade) => {
    setVisibleGrades((previous) => {
      const next = new Set(previous);
      if (next.has(grade)) next.delete(grade);
      else next.add(grade);
      return next;
    });
    setRenderStats(null); // 토글하면 다시 재야 하므로 이전 계측치를 지운다
  }, []);

  const metrics: Metrics | null =
    vulnerabilityOn && loadMs
      ? {
          ...loadMs,
          buildMs: renderStats?.buildMs ?? null,
          entityCount: renderStats?.entityCount ?? null,
          fps,
          minFps,
        }
      : null;

  return (
    <div style={{ position: "relative", width: "100vw", height: "100vh" }}>
      <Viewer ref={viewerRef} fullscreenButton animation={false} timeline={false}>
        {/* 부산 앱이므로 지구 전체가 아니라 부산에서 시작한다 */}
        <CameraFlyTo destination={BUSAN} duration={0} once />

        {vulnerabilityOn && grid && (
          <VulnerabilityGridLayer
            data={grid}
            visibleGrades={visibleGrades}
            onStats={setRenderStats}
            onPick={(props, gridId) => setPicked({ props, gridId })}
          />
        )}
      </Viewer>

      <LayerPanel activeLayers={activeLayers} onToggleLayer={toggleLayer}>
        {vulnerabilityOn && (
          <VulnerabilityControls
            meta={meta}
            visibleGrades={visibleGrades}
            onToggleGrade={toggleGrade}
            picked={picked}
          />
        )}
      </LayerPanel>

      <MetricsPanel metrics={metrics} />

      {error && (
        <div
          style={{
            position: "absolute",
            bottom: 12,
            left: 12,
            zIndex: 20,
            maxWidth: 520,
            padding: "10px 12px",
            background: "rgba(140,30,35,0.92)",
            color: "#fff",
            borderRadius: 8,
            font: "12px/1.5 system-ui, sans-serif",
            whiteSpace: "pre-wrap",
          }}
        >
          {error}
        </div>
      )}
    </div>
  );
}
