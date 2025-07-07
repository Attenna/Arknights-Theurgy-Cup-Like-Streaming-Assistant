shader_type canvas_item;

uniform float scroll_speed = 0.1; // 调整这个值来控制滚动速度

void fragment() {
    vec2 scrolled_uv = UV;
    scrolled_uv.x += TIME * scroll_speed; // 通过时间来改变X轴的UV坐标
    COLOR = texture(TEXTURE, scrolled_uv); // 从修改后的UV坐标采样纹理颜色
}