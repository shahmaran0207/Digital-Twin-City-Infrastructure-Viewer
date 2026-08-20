package com.busan.cityview.global.exception;

import org.springframework.http.HttpStatus;
import lombok.Getter;

/**
 * API 에러 코드 일원화 (설계 규칙 4번 — RFC 7807 ProblemDetail + code 확장 필드).
 *
 * <p>각 상수가 HTTP 상태와 기본 메시지를 함께 들고 있어,
 * 예외 핸들러는 분기 없이 {@code errorCode.getStatus()}로 응답 상태를 결정한다.
 *
 * <p>메시지는 개발자·로그용 영문으로 통일한다(기존 DTO 검증 메시지와 동일 기준).
 * 사용자에게 보일 한글 문구는 프론트가 {@code code} 값으로 매핑한다 — code 필드를 두는 이유.
 */

@Getter
public enum ErrorCode {

    //404
    FACILITY_NOT_FOUND(HttpStatus.NOT_FOUND, "Facility not found"),
    FACILITY_TYPE_NOT_FOUND(HttpStatus.NOT_FOUND, "Facility type not found"),

    //400
    INVALID_PARAMETER(HttpStatus.BAD_REQUEST, "Invalid request parameter"),
    INVALID_BBOX(HttpStatus.BAD_REQUEST, "Invalid bbox: min must be <=max"),

    //500
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occured");

    //에러 대응하는 HTTP 상태
    private final HttpStatus status;
    
    //기본 메시지. 구체적 상황은 예외 발생 지점에서 덮어쓸 수 있다.
    private final String message;

    ErrorCode(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

}