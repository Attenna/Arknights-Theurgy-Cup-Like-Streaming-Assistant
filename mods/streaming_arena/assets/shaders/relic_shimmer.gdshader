shader_type canvas_item;

// 流光扫过效果 —— 改造自老仓库 shaders/DecoBar.gdshader 的 TIME 滚动思路。
// 用途：给 "CivilightEterna" 立绘 TextureRect 挂 ShaderMaterial。
// 演示约定：插件自有 shader 一律放在本插件 assets/shaders/ 下，
// 场景以相对路径（../assets/shaders/...）引用，禁止硬编码 res://mods/...。

uniform float shimmer_speed = 0.35;                          // 流光扫过速度（循环/秒）
uniform float shimmer_width = 0.18;                          // 高光带宽度（UV 空间）
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.4; // 高光强度

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// 沿 X 轴循环滚动的一道高光带（0..1 周期）
	float band = fract(UV.x + TIME * shimmer_speed);
	float highlight = smoothstep(shimmer_width, 0.0, abs(band - 0.5)) * shimmer_strength;
	COLOR = vec4(tex.rgb + highlight, tex.a);
}
