package com.busan.cityview.global.exception;

import org.springframework.web.context.request.async.AsyncRequestNotUsableException;
import org.springframework.http.converter.HttpMessageNotWritableException;
import static org.assertj.core.api.Assertions.assertThat;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.DisplayName;
import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import org.springframework.http.ProblemDetail;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.slf4j.LoggerFactory;
import org.junit.jupiter.api.Test;
import java.io.IOException;

/**
 * GlobalExceptionHandler의 <b>로그 레벨 분기</b> 검증.
 *
 * <p>왜 로그를 테스트하는가: 이 변경의 계약이 "응답"이 아니라 "로그"에 있다.
 * 클라이언트가 끊은 경우와 진짜 서버 결함은 <b>둘 다 500 ProblemDetail을 돌려주므로</b>
 * 반환값으로는 구분되지 않는다. 구분되는 곳은 로그 레벨과 스택트레이스 유무뿐이다.
 *
 * <p>왜 중요한가: 격자 응답이 최대 5,000건이라 사용자가 받는 중에 페이지를 떠나는 일이
 * 평범하게 발생한다. 그걸 ERROR + 스택트레이스로 남기면 진짜 에러가 묻히고,
 * 중단 요청을 반복해 로그를 불리는 것도 가능해진다.
 *
 * <p>logback의 {@code ListAppender}를 핸들러 로거에 붙여 실제로 찍힌 이벤트를 들여다본다.
 */
class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    private Logger handlerLogger;
    private ListAppender<ILoggingEvent> appender;

    @BeforeEach
    void attachAppender() {
        handlerLogger = (Logger) LoggerFactory.getLogger(GlobalExceptionHandler.class);
        // DEBUG까지 받도록 낮춘다 — 끊김 관련 로그가 DEBUG로 나가는 것도 확인해야 한다
        handlerLogger.setLevel(Level.DEBUG);
        appender = new ListAppender<>();
        appender.start();
        handlerLogger.addAppender(appender);
    }

    @AfterEach
    void detachAppender() {
        handlerLogger.detachAppender(appender);
        appender.stop();
        handlerLogger.setLevel(null);   // 원래 설정(상위 로거 상속)으로 되돌린다
    }

    private ILoggingEvent onlyEvent() {
        assertThat(appender.list).hasSize(1);
        return appender.list.get(0);
    }

    @Test
    @DisplayName("클라이언트 끊김(IOException 원인)은 WARN이고 스택트레이스를 남기지 않는다")
    void clientDisconnectLogsWarnWithoutStackTrace() {
        // 실제로 관측된 모양: HttpMessageNotWritableException ← IOException(연결 중단)
        // 메시지는 한국어로 나왔다 — 그래서 구현이 메시지가 아니라 타입으로 판단한다
        Exception ex = new HttpMessageNotWritableException(
                "Could not write JSON",
                new IOException("현재 연결은 사용자의 호스트 시스템의 소프트웨어에 의해 중단되었습니다"));

        ProblemDetail result = handler.handleAll(ex);

        ILoggingEvent event = onlyEvent();
        assertThat(event.getLevel()).isEqualTo(Level.WARN);
        // 스택트레이스를 넘기지 않았는지 — 로그 이벤트에 throwable이 없어야 한다
        assertThat(event.getThrowableProxy()).isNull();
        assertThat(event.getFormattedMessage()).contains("연결을 끊었다");
        // 응답 자체는 500 그대로다(쓰이지 못할 뿐)
        assertThat(result.getStatus()).isEqualTo(500);
    }

    @Test
    @DisplayName("원인 체인이 깊어도 IOException을 찾아낸다")
    void clientDisconnectDetectedThroughNestedCauses() {
        Exception ex = new IllegalStateException("wrapper",
                new RuntimeException("middle",
                        new IOException("Connection reset by peer")));

        handler.handleAll(ex);

        assertThat(onlyEvent().getLevel()).isEqualTo(Level.WARN);
    }

    @Test
    @DisplayName("진짜 서버 결함은 ERROR이고 스택트레이스를 남긴다")
    void realFailureLogsErrorWithStackTrace() {
        Exception ex = new IllegalStateException("직렬화할 수 없는 타입");

        ProblemDetail result = handler.handleAll(ex);

        ILoggingEvent event = onlyEvent();
        assertThat(event.getLevel()).isEqualTo(Level.ERROR);
        // 원인 추적이 필요하므로 이쪽은 스택트레이스가 있어야 한다
        assertThat(event.getThrowableProxy()).isNotNull();
        assertThat(result.getStatus()).isEqualTo(500);
    }

    @Test
    @DisplayName("IOException이 없는 HttpMessageNotWritableException은 ERROR로 남는다")
    void serializationBugIsNotTreatedAsDisconnect() {
        // 직렬화 설정 오류 같은 진짜 버그. 끊김으로 오인해 덮으면 안 된다
        Exception ex = new HttpMessageNotWritableException("No serializer found for type");

        handler.handleAll(ex);

        assertThat(onlyEvent().getLevel()).isEqualTo(Level.ERROR);
    }

    @Test
    @DisplayName("AsyncRequestNotUsableException은 DEBUG로만 남기고 본문을 쓰지 않는다")
    void responseNotUsableLogsDebugOnly() {
        // 반환 타입이 void인 것이 핵심 — 연결이 없으니 본문을 쓸 수 없다
        handler.handleResponseNotUsable(
                new AsyncRequestNotUsableException("Response not usable after response errors"));

        ILoggingEvent event = onlyEvent();
        assertThat(event.getLevel()).isEqualTo(Level.DEBUG);
        assertThat(event.getThrowableProxy()).isNull();
    }
}
