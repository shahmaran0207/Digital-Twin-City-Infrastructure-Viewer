package com.busan.cityview.domain.facility.controller;

import com.busan.cityview.domain.facility.dto.FacilityDetailResponse;
import com.busan.cityview.domain.facility.dto.FacilityPointResponse;
import com.busan.cityview.domain.facility.service.FacilityService;
import com.busan.cityview.domain.facility.dto.FacilityQueryParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.busan.cityview.global.exception.BusinessException;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.GetMapping;
import com.busan.cityview.domain.facility.dto.BBoxParam;
import com.busan.cityview.global.exception.ErrorCode;
import com.busan.cityview.global.dto.ListResponse;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/facilities")
@RequiredArgsConstructor
public class FacilityController {

    private final FacilityService facilityService;

    //유형별 카테고리별 목록 조회
    @GetMapping
    public ListResponse<FacilityPointResponse> getFacilities(@Valid FacilityQueryParam query) {
        boolean hasType = query.getType() != null;
        boolean hasCategory = query.getCategory() != null;

        if (hasType == hasCategory) {
            throw new BusinessException(ErrorCode.INVALID_PARAMETER,
                    "exactly one of 'type' or 'category' is required");
        }

        int limit = query.effectiveLimit();
        return hasType
                ? facilityService.findByType(query.getType(), limit)
                : facilityService.findByCategory(query.getCategory(), limit);
    }

    //화면 영역(BBox) 조회 — 대용량 유형은 이 엔드포인트로 나눠 받는다
    @GetMapping("/in-bbox")
    public ListResponse<FacilityPointResponse> getFacilitiesInBBox(@Valid BBoxParam bbox,
                                                                   @Valid FacilityQueryParam query) {
        if (!bbox.isValid()) {
            throw new BusinessException(ErrorCode.INVALID_BBOX,
                    "minLng must be <= maxLng and minLat must be <= maxLat");
        }
        return facilityService.findInBBox(
                bbox.getMinLng(), bbox.getMinLat(),
                bbox.getMaxLng(), bbox.getMaxLat(),
                query.getType(), query.effectiveLimit());
    }

    //단건 상세 조회 — 없는 id면 404
    @GetMapping("/{id}")
    public FacilityDetailResponse getFacility(@PathVariable Long id) {
        return facilityService.findById(id);
    }
}
