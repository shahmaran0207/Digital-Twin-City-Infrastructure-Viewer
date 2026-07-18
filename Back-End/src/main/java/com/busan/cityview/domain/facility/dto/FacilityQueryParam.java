package com.busan.cityview.domain.facility.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;

/**
 * 시설물 조회 공통 쿼리 파라미터 DTO (security.md S2 3-4).
 *
 * <p>BBox와 함께 사용하거나, type/limit만 단독으로 사용할 수 있다.
 *
 * <p>컨트롤러 사용 예:
 * <pre>
 *   {@literal @}GetMapping("/facilities")
 *   public ResponseEntity<?> getFacilities(
 *       {@literal @}Valid BBoxParam bbox,
 *       {@literal @}Valid FacilityQueryParam query) { ... }
 * </pre>
 *
 * <p>limit 상한(MAX_LIMIT = 5000)은 DoS·메모리 폭발 방지를 위한 강제 상한이다.
 * 페이지네이션 미도입 단계에서 대용량 데이터(~59k 포인트) 전량 반환 방지.
 */
@Getter
@Setter
public class FacilityQueryParam {

    /**
     * 시설물 유형 필터.
     * 허용값: 영문 소문자·숫자·하이픈·밑줄만. SQL 인젝션 방지용 화이트리스트 패턴.
     * 예: "cctv", "bus_shelter", "school-zone"
     */
    @Pattern(
            regexp = "^[a-z0-9_\\-]{1,50}$",
            message = "type must be 1-50 characters: lowercase letters, digits, hyphens, underscores only"
    )
    private String type;

    /**
     * 카테고리 필터 (type보다 넓은 분류).
     * 허용값: 영문 소문자·숫자·하이픈·밑줄만.
     */
    @Pattern(
            regexp = "^[a-z0-9_\\-]{1,50}$",
            message = "category must be 1-50 characters: lowercase letters, digits, hyphens, underscores only"
    )
    private String category;

    /**
     * 결과 건수 상한.
     * 기본값: 1000, 최솟값: 1, 최댓값: 5000 (DoS 방지 — security.md S2 3-4).
     * 클라이언트가 limit을 명시하지 않으면 1000건 반환.
     */
    @Min(value = 1, message = "limit must be >= 1")
    @Max(value = 5000, message = "limit must be <= 5000")
    private Integer limit = 1000;  // 기본값 1000

    /** 실제 적용 limit: 요청값이 null이면 기본값 1000 반환 (서비스 레이어에서 사용). */
    public int effectiveLimit() {
        return limit != null ? limit : 1000;
    }
}
