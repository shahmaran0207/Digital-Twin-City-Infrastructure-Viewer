package com.busan.cityview.global.config;

import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;

@Configuration
public class CorsConfig {

    // 허용 오리진은 프로파일별 설정(app.cors.allowed-origins)에서 주입 — 하드코딩 제거 (V4)
    @Value("${app.cors.allowed-origins}")
    private String[] allowedOrigins;

    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                        .allowedOrigins(allowedOrigins)
                        // 공개된 것은 GET뿐이다. 쓰기 API 도입 시 그때 추가한다 (security.md 3-5)
                        .allowedMethods("GET");
            }
        };
    }
}
