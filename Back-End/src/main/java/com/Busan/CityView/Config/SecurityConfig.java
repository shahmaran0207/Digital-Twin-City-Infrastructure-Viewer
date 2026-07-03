package com.Busan.CityView.Config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 인증·인가 골격 (security.md 3-3, B안).
 *
 * <p>현 단계는 공개 GET 조회뿐이라 실제 보호 대상 API는 없다. 다만 쓰기/관리·앵커 트리거 API가
 * 생기는 순간을 대비해 골격만 미리 잡아둔다.
 *
 * <p>정책:
 * <ul>
 *   <li>GET 요청·swagger·health = 공개(permitAll) — 조회 API 특성상 무인증 허용</li>
 *   <li>그 외(POST/PUT/DELETE) = 인증 필요(authenticated) — 관리·쓰기·앵커 트리거 대비</li>
 *   <li>HTTP Basic + STATELESS(세션 미사용) + CSRF off — 쿠키 세션 없는 API 골격</li>
 * </ul>
 *
 * <p>관리 계정은 .env에서 BCrypt 해시로만 주입한다(평문 금지). 미설정 시 로그인만 불가할 뿐
 * 기동은 정상 — 보호 API가 없는 현 단계 개발에 지장을 주지 않기 위함.
 */
@Configuration
public class SecurityConfig {

    // 관리 계정 자격증명은 프로파일/.env에서 주입 (application.yml app.admin.*)
    @Value("${app.admin.username}")
    private String adminUsername;

    // BCrypt 해시(이미 인코딩된 값). 미설정 시 빈 문자열 → 어떤 비밀번호로도 로그인 실패(안전)
    @Value("${app.admin.password-hash}")
    private String adminPasswordHash;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        // 관리 계정 1개. password()에는 이미 인코딩된 BCrypt 해시를 그대로 넣는다(재인코딩 아님)
        UserDetails admin = User.withUsername(adminUsername)
                .password(adminPasswordHash)
                .roles("ADMIN")
                .build();
        return new InMemoryUserDetailsManager(admin);
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 쿠키 세션 미사용(Basic 인증 API) → CSRF 비활성화
                .csrf(csrf -> csrf.disable())
                // 세션을 만들지 않는 무상태 정책
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // 조회(GET)는 전면 공개 — 공개 공공데이터 조회 API 특성
                        .requestMatchers(HttpMethod.GET, "/api/**").permitAll()
                        // API 문서(swagger)·헬스체크 공개
                        .requestMatchers("/api/health", "/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                        // 그 외(쓰기·관리·앵커 트리거 등)는 인증 필요
                        .anyRequest().authenticated()
                )
                // HTTP Basic 인증
                .httpBasic(basic -> {});

        return http.build();
    }
}
