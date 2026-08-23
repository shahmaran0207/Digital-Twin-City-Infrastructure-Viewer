package com.busan.cityview.global.ratelimit;

import com.busan.cityview.global.exception.BusinessException;
import org.springframework.web.servlet.HandlerInterceptor;
import com.busan.cityview.global.exception.ErrorCode;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.concurrent.ConcurrentHashMap;
import io.github.bucket4j.ConsumptionProbe;
import io.github.bucket4j.Bucket;
import java.time.Duration;
import java.util.Map;

/**
 * IP당 요청 수 제한 (security.md 3-5B).
 *
 * <p>목록 조회 분당 30회, 단건 조회 분당 120회. 초과 시 429 + Retry-After.
 *
 * <p>IP는 getRemoteAddr()만 사용한다. X-Forwarded-For는 클라이언트가 조작할 수 있어
 * 그대로 믿으면 제한이 무력화된다. 리버스 프록시 뒤에서 운영할 때 프로파일로 분기한다.
 *
 * <p>한계: 단일 출처의 대량 수집을 막는 수준이며 분산 IP 공격은 WAF·CDN 영역이다.
 */
public class RateLimitInterceptor implements HandlerInterceptor {

    private static final int LIST_LIMIT_PER_MINUTE=30;
    private static final int DETAIL_LIMIT_PER_MINUTE=120;
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                             Object handler) {
        boolean isDetail = isDetailRequest(request.getRequestURI());
        int limit = isDetail ? DETAIL_LIMIT_PER_MINUTE : LIST_LIMIT_PER_MINUTE;

        String key = request.getRemoteAddr() + (isDetail ? ":detail" : ":list");
        Bucket bucket = buckets.computeIfAbsent(key, k -> newBucket(limit));
        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (!probe.isConsumed()) {
            // 최소 1초 보장 — 0을 주면 클라이언트가 즉시 재시도해 오히려 더 두들긴다
            long waitSeconds = Math.max(1, probe.getNanosToWaitForRefill() / 1_000_000_000L);
            response.setHeader("Retry-After", String.valueOf(waitSeconds));
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS,
                    "rate limit exceeded: " + limit + " requests per minute");
        }
        return true;
    }

    // /api/facilities/{숫자} 형태만 단건으로 본다.
    private boolean isDetailRequest(String uri) {
        return uri.matches("/api/facilities/\\d+");
    }

    // capacity = 한 번에 쌓아둘 수 있는 최대 토큰(버스트 허용량)
    // refillGreedy = 1분에 걸쳐 그만큼을 연속 보충 (초당 조금씩)
    private Bucket newBucket(int limitPerMinute) {
        return Bucket.builder()
                .addLimit(limit -> limit
                        .capacity(limitPerMinute)
                        .refillGreedy(limitPerMinute, Duration.ofMinutes(1)))
                .build();
    }
}
