package com.busan.cityview.domain.facility.dto;

import com.busan.cityview.domain.facility.entity.FacilityEntity;
import java.util.Map;

/**
 * 시설물 상세 응답 DTO — 단건 조회(GET /api/facilities/{id})용.
 *
 * <p>목록용 {@link FacilityPointResponse}와 달리 1건만 내려가므로
 * props·sourceId를 포함한 전체 정보를 담고, 유형도 한글명까지 쓸 수 있게
 * {@link FacilityTypeResponse}를 중첩한다.
 *
 * @param id       시설물 ID
 * @param type     시설물 유형 (코드·영문키·한글명·카테고리)
 * @param sourceId 원천 데이터의 id (출처 대조용)
 * @param sigungu  시군구
 * @param name     시설물 명칭 (없는 유형은 null)
 * @param lon      경도 (EPSG:4326)
 * @param lat      위도 (EPSG:4326)
 * @param props    유형별 추가 속성 (jsonb ↔ Map). 키 구성이 유형마다 달라 타입을 고정하지 않는다.
 */
public record FacilityDetailResponse(
    Long id,
    FacilityTypeResponse type,
    String sourceId,
    String sigungu,
    String name,
    Double lon,
    Double lat,
    Map<String, Object> props
) {

    /** FacilityEntity → DTO 변환 팩토리 메서드 */
    public static FacilityDetailResponse from(FacilityEntity entity) {
        return new FacilityDetailResponse(
            entity.getId(),
            FacilityTypeResponse.from(entity.getFacilityType()),
            entity.getSourceId(),
            entity.getSigungu(),
            entity.getName(),
            entity.getLon(),
            entity.getLat(),
            entity.getProps()
        );
    }
}
