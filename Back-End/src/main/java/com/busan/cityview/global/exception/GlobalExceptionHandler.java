package com.busan.cityview.global.exception;

import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ProblemDetail;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;

/**
 * 글로벌 예외 핸들러 — RFC 7807 ProblemDetail 형식으로 응답한다.
 * (설계 규칙: plans/phase0-redesign.md 4번 / 기존 커스텀 Map 응답을 대체)
 *
 * <p>응답 예시:
 * <pre>
 * {
 *   "type": "about:blank",
 *   "title": "Not Found",
 *   "status": 404,
 *   "detail": "facility 999 not found",
 *   "code": "FACILITY_NOT_FOUND"
 * }
 * </pre>
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    //ErrorCode + 상세 메시지로 ProblemDetail을 만드는 공통 헬퍼.
    private ProblemDetail toProblemDetail(ErrorCode errorCode, String detail) {
        ProblemDetail problemDetail =
                ProblemDetail.forStatusAndDetail(errorCode.getStatus(), detail);
        problemDetail.setProperty("code", errorCode.name());
        return problemDetail;
    }

    //서비스에서 명시적으로 던진 비즈니스 예외
    @ExceptionHandler(BusinessException.class)
    public ProblemDetail handleBusinessException(BusinessException ex){
        return toProblemDetail(ex.getErrorCode(), ex.getMessage());
    }

    //Valid DTO 검증 실패 — 필드별 오류를 한 문자열로 모아 detail에 담는다
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex){
        String detail = ex.getBindingResult().getFieldErrors().stream()
                .map(fieldError -> fieldError.getField() + ": " + fieldError.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return toProblemDetail(ErrorCode.INVALID_PARAMETER, detail);
    }

    //@RequestParam·@PathVariable 제약 위반 (@Min/@Max/@Pattern 등)
    @ExceptionHandler(ConstraintViolationException.class)
    public ProblemDetail handleConstraintViolation(ConstraintViolationException ex){
        String detail = ex.getConstraintViolations().stream()
                .map(violation -> violation.getPropertyPath() + ": " + violation.getMessage())
                .collect(Collectors.joining(", "));
        return toProblemDetail(ErrorCode.INVALID_PARAMETER, detail);
    }

    //필수 파라미터 누락
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ProblemDetail handleMissingParam(MissingServletRequestParameterException ex){
        return toProblemDetail(ErrorCode.INVALID_PARAMETER,
                "required parameter '" + ex.getParameterName() + "' is missing");
    }

    //나머지 모든 예외 -> 500
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleAll(Exception ex){
        log.error("처리되지 않은 예외", ex);
        return toProblemDetail(ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.getMessage());
    }

    //파라미터 타입 불일치 (예: /facilities/abc, limit=xyz)
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ProblemDetail handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        return toProblemDetail(ErrorCode.INVALID_PARAMETER,
                "'" + ex.getName() + "' has invalid type");
    }
}
