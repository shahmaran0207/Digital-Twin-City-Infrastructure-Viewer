package com.busan.cityview.domain.facility.dto;

import com.busan.cityview.domain.facility.entity.FacilityTypeEntity;

/**
 * 시설물 유형 응답 DTO.
 * 엔티티를 직접 반환하지 않고 이 DTO로 변환한다.
 * (JPA 프록시·불필요한 내부 구조 노출 방지)
 *
 * @param code       유형 코드 (숫자 PK)
 * @param name       영문 키 (예: safety_cctv)
 * @param nameKo     한글명 (예: 방범용 CCTV)
 * @param category   카테고리 영문 키 (예: safety)
 * @param categoryKo 카테고리 한글명 (예: 안전·방범)
 */
public record FacilityTypeResponse(
    Integer code,
    String name,
    String nameKo,
    String category,
    String categoryKo
) {
    /** FacilityTypeEntity → DTO 변환 팩토리 메서드 */
    public static FacilityTypeResponse from(FacilityTypeEntity entity) {
        return new FacilityTypeResponse(
            entity.getCode(),
            entity.getName(),
            entity.getNameKo(),
            entity.getCategory(),
            entity.getCategoryKo()
        );
    }
}