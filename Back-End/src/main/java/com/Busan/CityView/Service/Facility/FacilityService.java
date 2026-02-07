package com.Busan.CityView.Service.Facility;

import com.Busan.CityView.DTO.FacilityPointDTO;
import com.Busan.CityView.Repository.Facility.SafetyCctvRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class FacilityService {

    private final SafetyCctvRepository safetyCctvRepository;

    public List<FacilityPointDTO> getSafetyCctv() {
        return safetyCctvRepository.findAll()
                .stream()
                .map(e -> FacilityPointDTO.builder()
                        .id(e.getId())
                        .type("safety_cctv")
                        .sigungu(e.getSigungu())
                        .lon(e.getGeom().getX())
                        .lat(e.getGeom().getY())
                        .build())
                .toList();
    }
}