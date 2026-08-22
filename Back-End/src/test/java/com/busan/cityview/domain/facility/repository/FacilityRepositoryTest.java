package com.busan.cityview.domain.facility.repository;

import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import com.busan.cityview.domain.facility.entity.FacilityEntity;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import java.util.List;

/**
 * FacilityRepository 조회 쿼리 검증.
 *
 * <p>로컬 PG18에 직접 붙는다(replace = NONE). 실데이터가 적재돼 있어야 한다.
 * ddl-auto는 validate로 고정해 테스트가 스키마를 건드리지 못하게 한다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@TestPropertySource(properties = "spring.jpa.hibernate.ddl-auto=validate")
class FacilityRepositoryTest {
    @Autowired
    private FacilityRepository facilityRepository;
    @Test
    @DisplayName("유형별 조회 - limit만큼만 반환된다")
    void findByTypeName() {
        List<FacilityEntity> result = facilityRepository.findByTypeName("safety_cctv", 10);
        assertThat(result).hasSize(10);
        assertThat(result).allSatisfy(facility ->
                assertThat(facility.getFacilityType().getName()).isEqualTo("safety_cctv"));
    }
    @Test
    @DisplayName("BBox 조회 - 영역 안의 시설물만 반환된다")
    void findByBox() {
        // 부산 시청 주변 대략 범위
        List<FacilityEntity> result = facilityRepository.findByBox(
                129.05, 35.15, 129.10, 35.20, "safety_cctv", 10);
        assertThat(result).isNotEmpty();
        assertThat(result).allSatisfy(facility -> {
            assertThat(facility.getLon()).isBetween(129.05, 129.10);
            assertThat(facility.getLat()).isBetween(35.15, 35.20);
        });
    }
}
