package com.Busan.CityView.DTO;

import org.apache.ibatis.type.Alias;
import lombok.*;

@Data
@Builder
@EqualsAndHashCode(callSuper = false)
@AllArgsConstructor
@NoArgsConstructor
@Alias(value = "FacilityPoint")
public class FacilityPointDTO {

    private Long id;

    private String type;
    private String sigungu;

    private double lon;
    private double lat;


}
