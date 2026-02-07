package com.Busan.CityView.Controller.Facility;

import com.Busan.CityView.DTO.FacilityPointDTO;
import com.Busan.CityView.Service.Facility.FacilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/facilities")
@RequiredArgsConstructor
public class FacilityController {

    private final FacilityService facilityService;

    @GetMapping("/safety-cctv")
    public List<FacilityPointDTO> safetyCctv() {
        return facilityService.getSafetyCctv();
    }
}