shader_type canvas_item;

// 输入贴图
uniform sampler2D ring_shape_texture;
uniform sampler2D color_gradient_texture;

// 从 GDScript 传入的参数
uniform float color_texture_sample_degrees;  // 渐变旋转角度
uniform vec2 node_scale = vec2(1.0);        // 节点缩放值

void fragment() {
    // --- 关键修正：应用节点缩放到 UV ---
    // 计算缩放后的 UV（保持中心点不变）
    vec2 centered_uv = UV - vec2(0.5);
    vec2 scaled_uv = centered_uv / node_scale + vec2(0.5);

    // 采样形状贴图（受缩放影响）
    vec4 shape_albedo = texture(ring_shape_texture, scaled_uv);

    // --- 旋转渐变贴图（不受缩放影响）---
    vec2 base_screen_uv = SCREEN_UV;
    vec2 centered_screen_uv = base_screen_uv - vec2(0.5);
    float angle_rad = color_texture_sample_degrees * (3.14159265359 / 180.0);
    float cos_a = cos(angle_rad);
    float sin_a = sin(angle_rad);
    vec2 rotated_uv;
    rotated_uv.x = centered_screen_uv.x * cos_a - centered_screen_uv.y * sin_a;
    rotated_uv.y = centered_screen_uv.x * sin_a + centered_screen_uv.y * cos_a;
    vec2 final_gradient_uv = rotated_uv + vec2(0.5);

    // 采样渐变颜色
    vec4 gradient_albedo = texture(color_gradient_texture, final_gradient_uv);

    // 输出混合结果
    COLOR = gradient_albedo * shape_albedo.a;
}