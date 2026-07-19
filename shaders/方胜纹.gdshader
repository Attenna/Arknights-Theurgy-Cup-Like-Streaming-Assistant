shader_type canvas_item;

// 滚动速度：可以用滑动条控制正负流向，范围限制在 -1 到 1 之间
uniform float scroll_speed : hint_range(-1.0, 1.0) = 0.01;

// 整体透明度：限制在 0 到 1 之间的滑动条
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

// 线条颜色：：添加 source_color 激活内置的颜色选择器面板
uniform vec4 line_tint : source_color = vec4(1.0, 0.0, 0.0, 1.0);

// 提取线条的灰度阈值：限制在 0 到 1 之间的滑动条
uniform float line_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 scrolled_uv = UV;
    scrolled_uv.y += TIME * scroll_speed;
    vec4 tex_color = texture(TEXTURE, scrolled_uv);

    // 使用标准的 RGB 转灰度系数 (0.299, 0.587, 0.114) 会比纯 0.333 更符合人眼视觉
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 final_rgb;
    float tex_alpha = tex_color.a;

    if (gray < line_threshold) {
        final_rgb = line_tint.rgb;
    } else {
        final_rgb = vec3(0.0);
        tex_alpha = 0.0;
    }

    float final_alpha = tex_alpha * alpha * line_tint.a;
    COLOR = vec4(final_rgb, final_alpha);
}