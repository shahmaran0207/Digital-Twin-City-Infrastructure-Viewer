package com.busan.cityview.domain.facility.dto;

import com.busan.cityview.domain.facility.entity.FacilityEntity;

/**
 * 시설물 목록(포인트) 응답 DTO — 지도 렌더링용 경량 버전.
 *
 * <p>유형당 최대 5만 건 이상을 한 번에 내려보내므로 건당 필드를 최소화한다.
 * props·sourceId 같은 상세 정보는 담지 않고, 상세조회는 {@link FacilityDetailResponse}가 담당한다.
 *
 * @param id       시설물 ID (클릭 → 상세조회 키)
 * @param typeName 유형 영문 키 (예: safety_cctv) — 색상/아이콘 결정용
 * @param name     시설물 명칭 (없는 유형은 null)
 * @param lon      경도 (EPSG:4326)
 * @param lat      위도 (EPSG:4326)
 */
public record FacilityPointResponse(
    Long id,
    String typeName,
    String name,
    Double lon,
    Double lat
) {

    /** FacilityEntity → DTO 변환 팩토리 메서드 */
    public static FacilityPointResponse from(FacilityEntity entity) {
        return new FacilityPointResponse(
            entity.getId(),
            entity.getFacilityType().getName(),
            entity.getName(),
            entity.getLon(),
            entity.getLat()
        );
    }
}