import { Viewer } from "resium";
import { useEffect } from "react";
import { checkBackend } from "./api/test";
import type { CesiumComponentRef } from "resium";
import { Ion } from "cesium";
import type { Viewer as CesiumViewer } from "cesium"; 
import { useRef } from "react";

Ion.defaultAccessToken = import.meta.env.VITE_CESIUM_ION_TOKEN;

export default function App() {
  const viewerRef = useRef<CesiumComponentRef<CesiumViewer>>(null);

  useEffect(() => {
  checkBackend().then(console.log).catch(console.error);
}, []);

  return (
    <div style={{ width: "100vw", height: "100vh" }}>
      <Viewer
        ref={viewerRef}
        fullscreenButton
        animation={false}
        timeline={false}
      />
    </div>
  );
}
