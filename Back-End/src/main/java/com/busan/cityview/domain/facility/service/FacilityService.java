package com.busan.cityview.domain.facility.service;

import com.busan.cityview.domain.facility.repository.FacilityRepository;
import com.busan.cityview.domain.facility.dto.FacilityDetailResponse;
import com.busan.cityview.domain.facility.dto.FacilityPointResponse;
import org.springframework.transaction.annotation.Transactional;
import com.busan.cityview.global.exception.BusinessException;
import com.busan.cityview.global.exception.ErrorCode;
import com.busan.cityview.global.dto.ListResponse;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;
import java.util.List;

/**
 * 시설물 조회 서비스.
 *
 * <p>역할: 리포지토리에서 엔티티를 읽어 DTO로 변환하고, 목록은 ListResponse로 감싼다.
 * 컨트롤러는 HTTP만, 서비스는 조회 규칙만 담당한다.
 *
 * <p>모든 메서드가 읽기 전용이라 클래스 레벨에 readOnly 트랜잭션을 건다.
 * 엔티티 → DTO 변환은 반드시 트랜잭션 안에서 끝낸다 (LAZY 프록시 초기화 때문).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FacilityService {

    private final FacilityRepository facilityRepository;

    //단건 상세 조회
    public FacilityDetailResponse findById(Long id) {
        return facilityRepository.findById(id)
                .map(FacilityDetailResponse::from)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.FACILITY_NOT_FOUND, "facility " + id + " not found"));
    }

    //유형별 목록(type = facility_type.name)
    public ListResponse<FacilityPointResponse> findByType(String typeName, int limit) {
        List<FacilityPointResponse> items = facilityRepository.findByTypeName(typeName, limit + 1)
                .stream()
                .map(FacilityPointResponse::from)
                .toList();
        return ListResponse.of(items, limit);
    }

    //카테고리별 목록 (category = facility_type.category, 예: safety)
    public ListResponse<FacilityPointResponse> findByCategory(String category, int limit) {
        List<FacilityPointResponse> items = facilityRepository.findByCategory(category, limit + 1)
                .stream()
                .map(FacilityPointResponse::from)
                .toList();
        return ListResponse.of(items, limit);
    }

    //화면 영역(BBox) 조회 — typeName이 null이면 전체 유형
    public ListResponse<FacilityPointResponse> findInBBox(double minLng, double minLat,
                                                          double maxLng, double maxLat,
                                                          String typeName, int limit) {
        List<FacilityPointResponse> items = facilityRepository
                .findByBox(minLng, minLat, maxLng, maxLat, typeName, limit + 1)
                .stream()
                .map(FacilityPointResponse::from)
                .toList();
        return ListResponse.of(items, limit);
    }
}
