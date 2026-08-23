package com.busan.cityview.domain.facility.controller;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import com.busan.cityview.domain.facility.dto.FacilityPointResponse;
import com.busan.cityview.domain.facility.service.FacilityService;
import org.springframework.beans.factory.annotation.Autowired;
import com.busan.cityview.global.exception.BusinessException;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import com.busan.cityview.global.exception.ErrorCode;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyInt;
import com.busan.cityview.global.dto.ListResponse;
import static org.mockito.BDDMockito.given;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import java.util.List;

/**
 * FacilityController 슬라이스 테스트.
 *
 * <p>DB·서비스 없이 컨트롤러와 예외 핸들러만 띄운다. 서비스는 가짜(mock)로 대체하므로
 * 검증 대상은 "요청 파라미터 처리 + 상태 코드 + 응답 형식"이다.
 *
 * <p>검증 게이트를 수동 curl로만 확인하던 것을 자동화한다.
 */
@WebMvcTest(FacilityController.class)
@AutoConfigureMockMvc(addFilters = false)
public class FacilityControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private FacilityService facilityService;

    @Test
    @DisplayName("유형별 조회 - 200과 목록 래퍼 구조를 반환한다")
    void getFacilitiesByType() throws Exception {
        ListResponse<FacilityPointResponse> response = ListResponse.of(
                List.of(new FacilityPointResponse(1L, "safety_cctv", null, 129.07, 35.17)), 1000);
        given(facilityService.findByType(anyString(), anyInt())).willReturn(response);
        mockMvc.perform(get("/api/facilities").param("type", "safety_cctv"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.truncated").value(false))
                .andExpect(jsonPath("$.items[0].typeName").value("safety_cctv"));
    }

    @Test
    @DisplayName("type·category 둘 다 없으면 400")
    void getFacilitiesWithoutFilter() throws Exception {
        mockMvc.perform(get("/api/facilities"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    @Test
    @DisplayName("type·category 둘 다 있으면 400")
    void getFacilitiesWithBothFilters() throws Exception {
        mockMvc.perform(get("/api/facilities")
                        .param("type", "safety_cctv")
                        .param("category", "safety"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    @Test
    @DisplayName("limit 상한을 넘으면 400")
    void getFacilitiesWithTooLargeLimit() throws Exception {
        mockMvc.perform(get("/api/facilities")
                        .param("type", "safety_cctv")
                        .param("limit", "99999"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    @Test
    @DisplayName("없는 id 조회 - 404와 FACILITY_NOT_FOUND")
    void getFacilityNotFound() throws Exception {
        given(facilityService.findById(anyLong()))
                .willThrow(new BusinessException(ErrorCode.FACILITY_NOT_FOUND, "facility 999 not found"));
        mockMvc.perform(get("/api/facilities/999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("FACILITY_NOT_FOUND"))
                .andExpect(jsonPath("$.detail").value("facility 999 not found"));
    }

    @Test
    @DisplayName("BBox가 뒤집히면 400과 INVALID_BBOX")
    void getFacilitiesInInvalidBBox() throws Exception {
        mockMvc.perform(get("/api/facilities/in-bbox")
                        .param("minLng", "129.10").param("maxLng", "129.05")
                        .param("minLat", "35.15").param("maxLat", "35.20"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_BBOX"));
    }
}
