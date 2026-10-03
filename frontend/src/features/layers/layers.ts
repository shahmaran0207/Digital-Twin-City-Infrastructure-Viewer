/**
 * 레이어 목록.
 *
 * 이 서비스의 **기본**은 "부산 3D 공간 위에 시설물·장비·인프라를 시각화하고
 * 필터링·상세조회·위기레벨 색상 표시까지 제공하는 것"이다(README).
 * 범죄예방 환경 취약도·시뮬레이션·블록체인 앵커링은 그 위에 얹는 **확장**이다.
 * 대상 범위는 **부산 한정**이다.
 *
 * 레이어를 여기 한 곳에 데이터로 선언하는 이유: Phase가 진행되면 레이어가 차례로 붙는다.
 * 그때마다 패널 JSX를 뜯어고치지 않게 한다.
 *
 * 아직 구현되지 않은 것도 함께 보여준다 — 지금 켜진 레이어가 "전부"가 아니라는 것과
 * 뷰어의 범위가 어디까지인지가 화면만 봐도 드러난다.
 */

export type LayerId = 'facility' | 'crisis' | 'vulnerability' | 'simulation';

/** core = 서비스의 기본 기능 / extension = 그 위에 얹는 분석 */
export type LayerGroup = 'core' | 'extension';

export type LayerStatus = 'ready' | 'planned';

export interface LayerDef {
  id: LayerId;
  name: string;
  /** 패널에 한 줄로 붙는 설명 */
  summary: string;
  group: LayerGroup;
  status: LayerStatus;
  /** 어느 단계의 산출물인지 */
  phase: string;
}

export const LAYER_GROUP_LABEL: Record<LayerGroup, string> = {
  core: '기본',
  extension: '확장',
};

export const LAYERS: LayerDef[] = [
  // ── 기본 ────────────────────────────────────────────────────────────────
  {
    id: 'facility',
    name: '시설물·인프라',
    summary: 'CCTV·보안등·비상벨 등 23유형 294,577건 — 유형 필터 + 상세조회',
    group: 'core',
    status: 'planned',
    phase: 'Phase 1-C 적재 완료 · 레이어 미구현',
  },
  {
    id: 'crisis',
    name: '위기레벨',
    summary: '격자별 위기 등급 색상 표시',
    group: 'core',
    status: 'planned',
    phase: 'Phase 4',
  },
  // ── 확장 ────────────────────────────────────────────────────────────────
  {
    id: 'vulnerability',
    name: '범죄예방 환경 취약도',
    summary: '자전거 도난 관련 감시·조명 인프라 부족도 (250m 격자)',
    group: 'extension',
    status: 'ready',
    phase: 'Phase 4-B',
  },
  {
    id: 'simulation',
    name: '시뮬레이션',
    summary: '침수·그림자·대피 경로',
    group: 'extension',
    status: 'planned',
    phase: 'Phase 5',
  },
];
