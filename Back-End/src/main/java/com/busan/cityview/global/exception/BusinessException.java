package com.busan.cityview.global.exception;

import lombok.Getter;

/**
 * 비즈니스 예외 — {@link ErrorCode}를 들고 던지는 예외.
 *
 * <p>사용 예 (서비스):
 * <pre>
 *   throw new BusinessException(ErrorCode.FACILITY_NOT_FOUND, "facility " + id + " not found");
 * </pre>
 *
 * <p>예외 클래스를 종류별로 여러 개 만들지 않고 이 하나로 통일한다.
 * 무슨 에러인지는 {@code errorCode}가 구분하므로, 에러가 늘어도 클래스는 늘지 않는다.
 *
 * <p>{@code RuntimeException}(unchecked)을 상속하는 이유:
 * <ul>
 *   <li>checked 예외면 이 예외가 지나가는 모든 메서드에 {@code throws} 선언이 번져나간다</li>
 *   <li>Spring은 unchecked 예외에서만 트랜잭션을 자동 롤백한다</li>
 * </ul>
 */

@Getter
public class BusinessException extends RuntimeException {
    
    //에러 종류
    private final ErrorCode errorCode;

    //에러 코드 기본 메시지 그대로 사용
    public BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    //상황별 상세 메시지로 덮어쓰기
    public BusinessException(ErrorCode errorcode, String detail) {
        super(detail);
        this.errorCode = errorcode;
    }
}