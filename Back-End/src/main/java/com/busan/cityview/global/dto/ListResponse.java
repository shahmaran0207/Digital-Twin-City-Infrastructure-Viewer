package com.busan.cityview.global.dto;

import java.util.List;

/**
 * 목록 응답 공통 래퍼 (설계 규칙: plans/phase0-redesign.md 3번).
 *
 * <p>응답 형태:
 * <pre>
 * {
 *   "count": 5000,
 *   "truncated": true,
 *   "items": [ ... ]
 * }
 * </pre>
 *
 * <p>{@code count}는 응답에 담긴 items 건수다. DB 전체 건수가 아니다.
 * 전체 건수는 통계 API가 담당한다.
 *
 * @param count     응답에 담긴 건수
 * @param truncated limit에 걸려 잘렸는지 여부
 * @param items     실제 데이터 목록
 * @param <T>       담을 DTO 타입 (FacilityPointResponse, FacilityTypeResponse 등)
 */
public record ListResponse<T>(
        int count,
        boolean truncated,
        List<T> items
) {

    //limit + 1건 조회 결과를 받아 자르고 truncated 판정
    //<p> limit +1 : 정확히 limit건일때 잘린 것인지 딱 맞는것인지 판단위함
    public static <T> ListResponse<T> of(List<T> items, int limit) {
        boolean truncated = items.size() > limit;
        List<T> pageItems = truncated ? items.subList(0, limit) : items;
        return new ListResponse<>(pageItems.size(), truncated, pageItems);
    }
}
