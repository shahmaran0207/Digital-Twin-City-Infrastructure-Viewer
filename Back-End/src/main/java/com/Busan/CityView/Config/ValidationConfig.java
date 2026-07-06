package com.Busan.CityView.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.validation.beanvalidation.MethodValidationPostProcessor;

/**
 * 메서드 레벨 Bean Validation 활성화 (security.md S2 3-4).
 *
 * <p>{@link MethodValidationPostProcessor}를 등록하면 컨트롤러에 {@code @Validated}를 붙였을 때
 * {@code @RequestParam}, {@code @PathVariable}에 달린 {@code @Min}·{@code @Max}·{@code @Pattern} 등
 * 제약 어노테이션이 실제로 검증된다.
 *
 * <p>검증 실패 시 {@link jakarta.validation.ConstraintViolationException}이 던져지고
 * {@link com.Busan.CityView.Exception.GlobalExceptionHandler}가 400으로 응답한다.
 *
 * <p>사용 예 — 컨트롤러:
 * <pre>
 *   {@literal @}RestController
 *   {@literal @}Validated   // ← 이 어노테이션이 있어야 @Min/@Max/@Pattern 검증이 작동
 *   {@literal @}RequestMapping("/api/facilities")
 *   public class FacilityController {
 *
 *       {@literal @}GetMapping
 *       public ResponseEntity<?> list(
 *           {@literal @}RequestParam(defaultValue = "1000")
 *           {@literal @}Min(1) {@literal @}Max(5000) int limit,
 *
 *           {@literal @}RequestParam(required = false)
 *           {@literal @}Pattern(regexp = "^[a-z0-9_\\-]{1,50}$") String type,
 *
 *           {@literal @}Valid BBoxParam bbox   // ← DTO는 @Valid로 검증
 *       ) { ... }
 *   }
 * </pre>
 */
@Configuration
public class ValidationConfig {

    @Bean
    public MethodValidationPostProcessor methodValidationPostProcessor() {
        return new MethodValidationPostProcessor();
    }
}
