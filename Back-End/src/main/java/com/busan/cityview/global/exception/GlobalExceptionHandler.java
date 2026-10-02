package com.busan.cityview.global.exception;

import org.springframework.web.context.request.async.AsyncRequestNotUsableException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ProblemDetail;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import java.io.IOException;

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

    /** 예외 원인 체인을 훑을 최대 깊이 — 체인이 순환하는 병리적 경우에 무한 루프를 막는다 */
    private static final int MAX_CAUSE_DEPTH = 10;

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

    /**
     * 이미 끊긴 연결에 응답을 쓰려다 난 예외. 로그만 남기고 끝낸다.
     *
     * <p>{@code void} 반환이라 응답 본문을 쓰지 않는다 — 연결이 없으니 쓸 수도 없다.
     * ProblemDetail을 돌려주면 그 쓰기가 또 실패해 같은 예외가 반복된다.
     */
    @ExceptionHandler(AsyncRequestNotUsableException.class)
    public void handleResponseNotUsable(AsyncRequestNotUsableException ex){
        log.debug("응답을 쓸 수 없다(연결 종료 후): {}", ex.getMessage());
    }

    //나머지 모든 예외 -> 500
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleAll(Exception ex){
        // 클라이언트가 먼저 끊은 경우는 서버 결함이 아니다. 스택트레이스 없이 한 줄만 남긴다.
        if (isClientDisconnect(ex)) {
            log.warn("클라이언트가 응답 수신 중 연결을 끊었다 ({}): {}",
                    ex.getClass().getSimpleName(), rootCauseMessage(ex));
        } else {
            log.error("처리되지 않은 예외", ex);
        }
        // 끊긴 경우 이 응답은 쓰이지 못하고 AsyncRequestNotUsableException이 되어 위 핸들러가 받는다.
        // 분기해서 void를 돌려줄 수는 없으므로(반환 타입이 하나다) 그대로 둔다 — 무해하고 DEBUG로만 남는다.
        return toProblemDetail(ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.getMessage());
    }

    /**
     * 클라이언트가 응답을 다 받기 전에 연결을 끊었는지 판단한다.
     *
     * <p><b>메시지로 판단하지 않는다.</b> 흔히 쓰는 "Broken pipe"·"Connection reset" 문자열 비교는
     * JVM 로케일에 따라 메시지가 번역되므로 못 쓴다. 이 환경은 한국어라 실제로
     * {@code "현재 연결은 사용자의 호스트 시스템의 소프트웨어에 의해 중단되었습니다"} 로 나온다.
     * 그래서 <b>타입</b>으로만 본다.
     *
     * <p>원인 체인에 {@link IOException}이 있으면 끊김으로 본다. 요청 처리 중 발생하는 IOException은
     * 사실상 응답 쓰기 실패뿐이다 — DB 오류는 {@code SQLException}이고 이 앱은 요청 경로에서 파일 IO를 하지 않는다.
     * Tomcat의 {@code ClientAbortException}도 IOException 하위라 따로 import하지 않고 함께 걸린다
     * (컨테이너 클래스에 의존하지 않으려는 의도).
     */
    private boolean isClientDisconnect(Throwable ex) {
        Throwable cause = ex;
        for (int depth = 0; cause != null && depth <= MAX_CAUSE_DEPTH; depth++) {
            if (cause instanceof IOException) {
                return true;
            }
            cause = cause.getCause();
        }
        return false;
    }

    //가장 안쪽 원인의 메시지 — 끊김 사유를 한 줄로 남기기 위함
    private String rootCauseMessage(Throwable ex) {
        Throwable root = ex;
        for (int depth = 0; root.getCause() != null && depth <= MAX_CAUSE_DEPTH; depth++) {
            root = root.getCause();
        }
        return root.getMessage();
    }

    //파라미터 타입 불일치 (예: /facilities/abc, limit=xyz)
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ProblemDetail handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        return toProblemDetail(ErrorCode.INVALID_PARAMETER,
                "'" + ex.getName() + "' has invalid type");
    }
}
