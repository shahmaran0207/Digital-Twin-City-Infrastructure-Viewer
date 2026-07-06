package com.Busan.CityView.Exception;

import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * 글로벌 예외 핸들러 (security.md S2 3-4 / V9 에러 처리).
 *
 * <p>정책:
 * <ul>
 *   <li>입력 검증 실패(@Valid, @Validated) → 400 + 필드별 오류 목록</li>
 *   <li>경로/쿼리 파라미터 제약 위반(@Min/@Max/@Pattern 등) → 400 + 메시지</li>
 *   <li>타입 불일치(문자열을 숫자 파라미터에) → 400</li>
 *   <li>필수 파라미터 누락 → 400</li>
 *   <li>비즈니스 예외(IllegalArgumentException) → 400</li>
 *   <li>그 외 → 500. 스택트레이스·내부 정보는 절대 응답에 포함하지 않음 (V9)</li>
 * </ul>
 *
 * <p>응답 형식: {@code { "status": 400, "error": "Bad Request", "message": "...", "timestamp": "..." }}
 * <br>검증 실패 시 추가 필드: {@code "details": [ { "field": "...", "message": "..." }, ... ]}
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    // ── 1. @Valid / @Validated DTO 검증 실패 ──────────────────────────────────
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex) {

        List<Map<String, String>> details = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> Map.of(
                        "field", fe.getField(),
                        "message", fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid value"
                ))
                .toList();

        return badRequest("Validation failed", details);
    }

    // ── 2. @RequestParam / @PathVariable 제약 위반 (@Min/@Max/@Pattern 등) ────
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraintViolation(
            ConstraintViolationException ex) {

        List<Map<String, String>> details = ex.getConstraintViolations().stream()
                .map(cv -> {
                    // 경로에서 파라미터 이름만 추출 (예: "methodName.paramName" → "paramName")
                    String path = cv.getPropertyPath().toString();
                    String param = path.contains(".") ? path.substring(path.lastIndexOf('.') + 1) : path;
                    return Map.of("field", param, "message", cv.getMessage());
                })
                .toList();

        return badRequest("Parameter constraint violation", details);
    }

    // ── 3. 파라미터 타입 불일치 (예: limit=abc) ───────────────────────────────
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, Object>> handleTypeMismatch(
            MethodArgumentTypeMismatchException ex) {

        String message = String.format("'%s' must be of type %s",
                ex.getName(),
                ex.getRequiredType() != null ? ex.getRequiredType().getSimpleName() : "unknown");
        return badRequest(message, null);
    }

    // ── 4. 필수 파라미터 누락 ─────────────────────────────────────────────────
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<Map<String, Object>> handleMissingParam(
            MissingServletRequestParameterException ex) {

        return badRequest(
                String.format("Required parameter '%s' is missing", ex.getParameterName()),
                null);
    }

    // ── 5. 비즈니스 입력 오류 (서비스에서 직접 던지는 경우) ──────────────────
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgument(IllegalArgumentException ex) {
        return badRequest(ex.getMessage(), null);
    }

    // ── 6. 그 외 모든 예외 → 500. 내부 정보 노출 금지 (V9) ───────────────────
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleAll(Exception ex) {
        // 로그는 서버 측에서만 남기고, 응답에는 일반 메시지만 반환
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorBody(500, "Internal Server Error", "An unexpected error occurred.", null));
    }

    // ── 헬퍼 ─────────────────────────────────────────────────────────────────
    private ResponseEntity<Map<String, Object>> badRequest(String message,
                                                           List<Map<String, String>> details) {
        return ResponseEntity.badRequest().body(errorBody(400, "Bad Request", message, details));
    }

    private Map<String, Object> errorBody(int status, String error, String message,
                                          List<Map<String, String>> details) {
        if (details != null) {
            return Map.of(
                    "status", status,
                    "error", error,
                    "message", message,
                    "details", details,
                    "timestamp", Instant.now().toString()
            );
        }
        return Map.of(
                "status", status,
                "error", error,
                "message", message,
                "timestamp", Instant.now().toString()
        );
    }
}
