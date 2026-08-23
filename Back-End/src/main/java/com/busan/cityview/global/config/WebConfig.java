package com.busan.cityview.global.config;

import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import com.busan.cityview.global.ratelimit.RateLimitInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;

/**
 * 웹 계층 공통 설정 — 인터셉터 등록.
 *
 * <p>레이트 리밋은 조회 API(/api/facilities/**)에만 적용한다.
 * /api/health 는 모니터링·기동 확인용이라 제외한다.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Bean
    public RateLimitInterceptor rateLimitInterceptor(){
        return new RateLimitInterceptor();
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(rateLimitInterceptor())
                .addPathPatterns("/api/facilities/**", "/api/facilities");
    }
}
