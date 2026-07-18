package com.busan.cityview.domain.facility.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * 공간 쿼리용 BoundingBox 파라미터 DTO (security.md S2 3-4).
 *
 * <p>부산 전체 범위 기준으로 좌표 범위를 제한한다.
 * 실제 부산 위경도 범위보다 여유를 두어 경계 쿼리를 허용한다.
 * <pre>
 *   GET /api/.../bbox?minLng=128.7&minLat=34.8&maxLng=129.4&maxLat=35.4
 * </pre>
 *
 * <p>컨트롤러에서 사용 예:
 * <pre>
 *   {@literal @}GetMapping("/facilities")
 *   {@literal @}Validated
 *   public List<...> getFacilities({@literal @}Valid BBoxParam bbox, ...) { ... }
 * </pre>
 *
 * <p>네이티브 쿼리(PostGIS ST_Within 등)에서는 반드시 바인딩 파라미터만 사용:
 * <pre>
 *   // ✅ 올바른 방법
 *   @Query(value = "SELECT * FROM facility WHERE ST_Within(geom, ST_MakeEnvelope(:minLng,:minLat,:maxLng,:maxLat,4326))",
 *          nativeQuery = true)
 *   List&lt;Facility&gt; findByBBox(@Param("minLng") double minLng, ...);
 *
 *   // ❌ 절대 금지 — SQLi 위험
 *   "SELECT * FROM facility WHERE ... AND type = '" + type + "'"
 * </pre>
 */
@Getter
@Setter
public class BBoxParam {

    // ── 경도(Longitude) 범위: 부산 약 128.7~129.5 ───────────────────────────

    @NotNull(message = "minLng is required")
    @DecimalMin(value = "124.0", message = "minLng must be >= 124.0 (Korean peninsula west)")
    @DecimalMax(value = "132.0", message = "minLng must be <= 132.0 (Korean peninsula east)")
    private Double minLng;

    @NotNull(message = "maxLng is required")
    @DecimalMin(value = "124.0", message = "maxLng must be >= 124.0")
    @DecimalMax(value = "132.0", message = "maxLng must be <= 132.0")
    private Double maxLng;

    // ── 위도(Latitude) 범위: 부산 약 34.8~35.4 ──────────────────────────────

    @NotNull(message = "minLat is required")
    @DecimalMin(value = "33.0", message = "minLat must be >= 33.0 (Jeju 이남)")
    @DecimalMax(value = "38.6", message = "minLat must be <= 38.6 (Korean peninsula north)")
    private Double minLat;

    @NotNull(message = "maxLat is required")
    @DecimalMin(value = "33.0", message = "maxLat must be >= 33.0")
    @DecimalMax(value = "38.6", message = "maxLat must be <= 38.6")
    private Double maxLat;

    /**
     * min이 max를 초과하는 경우 방어 (서비스에서 호출하거나 @AssertTrue 대안으로 사용).
     *
     * <p>컨트롤러 또는 서비스에서 수동 호출:
     * <pre>
     *   if (!bbox.isValid()) throw new IllegalArgumentException("minLng must be <= maxLng and minLat must be <= maxLat");
     * </pre>
     */
    public boolean isValid() {
        return minLng != null && maxLng != null && minLat != null && maxLat != null
                && minLng <= maxLng
                && minLat <= maxLat;
    }
}
