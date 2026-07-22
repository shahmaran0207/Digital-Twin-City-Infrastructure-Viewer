package com.busan.cityview.domain.facility.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.NoArgsConstructor;
import jakarta.persistence.Id;
import lombok.AccessLevel;
import lombok.Getter;

/**
 * 시설물 유형 룩업 엔티티 — digital_twin.facility_type 매핑.
 *
 * <p>code는 원천 CSV의 facility_type 값을 그대로 쓰는 자연키(수동 시드값)이므로
 * 자동 증가(@GeneratedValue)를 붙이지 않는다.
 * 조회 전용 테이블이라 setter 없이 @Getter만 둔다.
 */
@Entity
@Table(schema = "digital_twin", name = "facility_type")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // JPA 요구 기본 생성자 (외부 생성 차단)
public class FacilityTypeEntity {

    /** 시설물 타입 코드 (원천 CSV의 facility_type 값, 자연키) */
    @Id
    @Column(name="code")
    private Integer code;

     /** 시설물 유형 영문 키 (API/프론트 레이어 키) */
    @Column(name="name", nullable=false, length=50)
    private String name;

    /** 시설물 유형 한글명 */
    @Column(name="name_ko", nullable=false, length=100)
    private String nameKo;

    /** 레이어 카테고리 영문 키 (traffic/safety/road_facility/transit/living) */
    @Column(name="category", nullable=false, length=30)
    private String category;

    /** 레이어 카테고리 한글명 */
    @Column(name="category_ko", nullable=false, length=50)
    private String categoryKo;
}