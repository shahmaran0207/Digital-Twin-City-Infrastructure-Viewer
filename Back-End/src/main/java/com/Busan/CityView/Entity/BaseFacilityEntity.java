package com.Busan.CityView.Entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.locationtech.jts.geom.Point;

@MappedSuperclass
@Getter
@Setter
public abstract class BaseFacilityEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    protected Long id;

    protected String sigungu;

    @Column(columnDefinition = "geometry(Point,4326)")
    protected Point geom;
}