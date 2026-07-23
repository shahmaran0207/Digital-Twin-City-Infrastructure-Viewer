package com.busan.cityview.domain.facility.entity;

import io.hypersistence.utils.hibernate.type.json.JsonType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import org.hibernate.annotations.Type;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.FetchType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.NoArgsConstructor;
import jakarta.persistence.Id;
import lombok.AccessLevel;
import lombok.Getter;
import java.util.Map;

/**
 * 통합 시설물 엔티티 — digital_twin.facility 매핑.
 *
 * <p>매핑 규칙
 * <ul>
 *   <li>id: DB가 IDENTITY로 자동 증가 → GenerationType.IDENTITY</li>
 *   <li>facilityType: category 조인 조회를 위해 int 컬럼이 아니라 @ManyToOne 엔티티로 매핑</li>
 *   <li>props: jsonb ↔ Map 매핑 (hypersistence JsonType)</li>
 *   <li>geom: DB의 GENERATED 컬럼이라 매핑하지 않는다. 좌표는 lon/lat로만 다룬다.</li>
 * </ul>
 */
@Entity
@Table(schema = "digital_twin", name = "facility")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // JPA 요구 기본 생성자 (외부 생성 차단)
public class FacilityEntity {

    /** 내부 고유 ID (DB 자동 증가) */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name="id")
    private Long id;

    /** 시설물 유형 (facility_type.code 참조) — category 조인 조회용 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "facility_type", referencedColumnName = "code", nullable = false)
    private FacilityTypeEntity facilityType;

    /** 원천 데이터의 id */
    @Column(name="source_id", length=50)
    private String sourceId;

    /** 시군구 */
    @Column(name="sigungu", length=50)
    private String sigungu;

     /** 시설물 명칭 (있는 경우) */
    @Column(name = "name", length = 200)
    private String name;

    /** 경도 (EPSG:4326) */
    @Column(name = "lon", nullable = false)
    private Double lon;
    
    /** 위도 (EPSG:4326) */
    @Column(name = "lat", nullable = false)
    private Double lat;

    /** 시설물별 추가 속성 (jsonb ↔ Map). 예: ITS CCTV 스트림 url */
    @Type(JsonType.class)
    @Column(name = "props", columnDefinition = "jsonb")
    private Map<String, Object> props;
}