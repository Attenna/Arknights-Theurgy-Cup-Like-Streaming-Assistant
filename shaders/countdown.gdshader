shader_type canvas_item;

// 渐变色设置（从上到下的渐变）
uniform vec4 text_color_top : source_color = vec4(1.0, 1.0, 1.0, 1.0);    // 字体顶部颜色（默认白）
uniform vec4 text_color_bottom : source_color = vec4(0.8, 0.8, 0.8, 1.0); // 字体底部颜色（默认浅灰，可改你想要的颜色）

// 外发光设置
uniform vec4 glow_color : source_color = vec4(0.125, 0.757, 0.443, 1.0); // 发光/描边颜色（默认绿色）
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;               // 发光强度
uniform float glow_radius : hint_range(0.0, 10.0) = 3.0;                // 发光/描边范围
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;                // 呼吸动画速度

void fragment() {
    // 1. 获取当前像素的纹理情况
    vec4 current_color = texture(TEXTURE, UV);

    // 2. 计算字体本身的渐变色（依据 UV.y 从上到下线性混合）
    vec3 base_text_rgb = mix(text_color_top.rgb, text_color_bottom.rgb, UV.y);
    float base_text_alpha = mix(text_color_top.a, text_color_bottom.a, UV.y);

    // 3. 采样周围像素计算发光边缘
    float alpha_sum = 0.0;
    float total_samples = 0.0;
    vec2 size = TEXTURE_PIXEL_SIZE * glow_radius;

    for(float x = -1.0; x <= 1.0; x += 1.0) {
        for(float y = -1.0; y <= 1.0; y += 1.0) {
            vec2 offset = vec2(x, y) * size;
            alpha_sum += texture(TEXTURE, UV + offset).a;
            total_samples += 1.0;
        }
    }
    float blur_alpha = alpha_sum / total_samples;

    // 4. 呼吸灯动画计算
    float pulse = 0.75 + 0.25 * cos(TIME * pulse_speed);
    float final_glow_intensity = glow_intensity * pulse;

    // 5. 混合“渐变字色”与“发光色”
    // 当 current_color.a 为 1 时完全显示渐变字，为 0 时显示外围发光
    vec3 mixed_rgb = mix(glow_color.rgb * final_glow_intensity, base_text_rgb, current_color.a);

    // 6. 最终透明度计算
    float final_alpha = max(current_color.a * base_text_alpha, blur_alpha * glow_color.a * min(1.0, final_glow_intensity));

    COLOR = vec4(mixed_rgb, final_alpha);
}