package com.busan.cityview.domain.facility.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.busan.cityview.domain.facility.entity.FacilityEntity;

/**
 * 시설물 조회 리포지토리.
 *
 * <p>메서드 설명
 * <ul>
 *   <li>{@code findByFacilityType_Name} — facility_type.name(영문 코드)으로 필터. JPQL이 알아서 JOIN.</li>
 *   <li>{@code findByFacilityType_Category} — 카테고리 단위 조회.</li>
 *   <li>{@code findByBBox} — 화면 영역 조회. ST_MakeEnvelope로 BBox 폴리곤을 만들고
 *       &&(겹침) 연산자로 GIST 인덱스를 탄다. LIMIT은 DoS 방지용.</li>
 * </ul>
 *
 * <p>네이티브 쿼리 주의사항: 파라미터는 반드시 :name 바인딩만 사용.
 * 문자열 연결(+ type + 등)은 금지 — SQL 인젝션 위험 (security.md S2 3-4).
 */
public interface FacilityRepository extends JpaRepository<FacilityEntity, Long> {

     /**
     * 유형별 조회 (type = facility_type.name 영문 키).
     * 예: "safety_cctv", "its_cctv"
     * LIMIT은 서비스에서 결과를 자르지 않고 DB 단에서 잘라 성능을 보호한다.
     */
    @Query("""
            SELECT f FROM FacilityEntity f
            JOIN FETCH f.facilityType ft
            WHERE ft.name = :typeName
            ORDER  BY f.id
            LIMIT :limit
            """)
    List<FacilityEntity> findByTypeName(@Param("typeName") String typeName,
                                        @Param("limit") int limit);

    
    /**
     * 카테고리별 조회 (category = facility_type.category 영문 키).
     * 예: "safety", "traffic"
     */
    @Query("""
            SELECT f from FacilityEntity f
            JOIN FETCH f.facilityType ft
            WHERE ft.category = :category
            ORDER BY f.id
            LIMIT :limit
            """)
    List<FacilityEntity> findByCategory(@Param("category") String category,
                                        @Param("limit") int limit);

    
     /**
     * BBox 영역 내 시설물 조회 (PostGIS GIST 인덱스 활용).
     *
     * <p>geom 컬럼은 DB의 GENERATED 컬럼(lon/lat → Point)이라 JPA 매핑은 없지만
     * 네이티브 쿼리에서는 직접 참조할 수 있다.
     *
     * <p>쿼리 설명:
     * <ul>
     *   <li>ST_MakeEnvelope(minLng, minLat, maxLng, maxLat, 4326) — SRID 4326으로 BBox 폴리곤 생성</li>
     *   <li>&& — 두 geometry가 겹치는지 확인 (GIST 인덱스 사용, ST_Intersects보다 빠름)</li>
     *   <li>:typeName IS NULL — type 파라미터가 없으면 전체 유형 반환</li>
     * </ul>
     */
    @Query(value="""
            SELECT f.* FROM digital_twin.facility f
            JOIN digital_twin.facility_type ft ON f.facility_type = ft.code
            WHERE f.geom && ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326)
                AND (:typeName IS NULL OR ft.name = :typeName)
            ORDER BY f.id
            LIMIT :limit
            """,
        nativeQuery = true)
    List<FacilityEntity> findByBox(@Param("minLng") double minLng,
                                    @Param("minLat") double minLat,
                                    @Param("maxLng") double maxLng,
                                    @Param("maxLat") double maxLat,
                                    @Param("typeName") String typeName,
                                    @Param("limit") int limit);
}