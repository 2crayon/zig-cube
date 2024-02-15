const std = @import("std");

const Vec3 = @Vector(3, f64);
const Vec2 = @Vector(2, f64);

const WIDTH = 75;
const HEIGHT = 75;
const CENTER_X = WIDTH / 2;
const CENTER_Y = HEIGHT / 2;

const FINAL_SCALE = 30;

const RED = rgb(255, 0, 0);
const BLUE = rgb(0, 0, 255);
const WHITE = rgb(255, 255, 255);

const POINTS: [8]Vec3 = .{
    Vec3{ 0.5, 0.5, 0.5 },
    Vec3{ 0.5, 0.5, -0.5 },
    Vec3{ 0.5, -0.5, 0.5 },
    Vec3{ 0.5, -0.5, -0.5 },
    Vec3{ -0.5, 0.5, 0.5 },
    Vec3{ -0.5, 0.5, -0.5 },
    Vec3{ -0.5, -0.5, 0.5 },
    Vec3{ -0.5, -0.5, -0.5 },
};
const POINT_COLORS: [POINTS.len]u32 = .{
    rgb(200, 200, 70),
    rgb(70, 255, 70),
    rgb(255, 70, 70),
    WHITE,
    WHITE,
    rgb(70, 200, 200),
    rgb(70, 70, 255),
    rgb(200, 70, 200),
};
const LINES: [12][2]usize = .{
    .{ 0, 1 },
    .{ 0, 2 },
    .{ 1, 3 },
    .{ 0, 4 },
    .{ 1, 5 },
    .{ 7, 6 },
    .{ 7, 5 },
    .{ 6, 4 },
    .{ 7, 3 },
    .{ 6, 2 },
    .{ 2, 3 },
    .{ 4, 5 },
};

// ---- Global State ----
var pixels: [WIDTH * HEIGHT]u32 = undefined;
var zbuffer: [pixels.len]f64 = undefined;
var angle_x: f64 = 0.9;
var angle_y: f64 = 0;
var angle_z: f64 = 0;
var camera_distance: f64 = 1.5;

fn rgb(r: u8, g: u8, b: u8) u32 {
    var out: u32 = 0;

    const r_mask: u32 = @intCast(r);
    var g_mask: u32 = @intCast(g);
    g_mask = g_mask << 8;
    var b_mask: u32 = @intCast(b);
    b_mask = b_mask << 16;

    out = out | r_mask | g_mask | b_mask | 0xFF000000;
    return out;
}

fn fill(color: u32) void {
    @memset(&pixels, color);
}

fn draw_line(x1: i32, y1: i32, z_pos1: f64, color1: u32, x2: i32, y2: i32, z_pos2: f64, color2: u32) void {
    if (x1 == x2 and y1 == y2) {
        draw_point(x1, y1, mix(color1, color2, 0.5), (z_pos1 + z_pos2) / 2);
        return;
    }

    const m: f32 =
        @as(f32, @floatFromInt(y2 - y1)) / @as(f32, @floatFromInt(x2 - x1));
    const b: f32 =
        @as(f32, @floatFromInt(y1)) - m * @as(f32, @floatFromInt(x1));

    const is_steep = @abs(m) > 1;

    if (!is_steep) {
        const dist: i32 = @intCast(@abs(x2 - x1));
        const hx = if (x1 > x2) x1 else x2;
        const lx = if (x1 > x2) x2 else x1;

        var x = lx;
        while (x <= hx) : (x += 1) {
            const y: i32 = @intFromFloat(@round(m * @as(f32, @floatFromInt(x)) + b));
            var amount =
                @as(f32, @floatFromInt(dist - x + lx)) / @as(f32, @floatFromInt(dist));
            if (x1 > x2) amount = 1 - amount;
            draw_point(
                x,
                y,
                mix(color1, color2, amount),
                z_pos1 * amount + z_pos2 * (1 - amount),
            );
        }
    } else {
        const dist: i32 = @intCast(@abs(y2 - y1));
        const hy = if (y1 > y2) y1 else y2;
        const ly = if (y1 > y2) y2 else y1;

        const is_vertical = x1 == x2;
        var y = ly;
        while (y <= hy) : (y += 1) {
            const x: i32 = if (is_vertical) x1 else @intFromFloat(@round((@as(f32, @floatFromInt(y)) - b) / m));
            var amount =
                @as(f32, @floatFromInt(dist - y + ly)) / @as(f32, @floatFromInt(dist));
            if (y1 > y2) amount = 1 - amount;
            draw_point(
                x,
                y,
                mix(color1, color2, amount),
                z_pos1 * amount + z_pos2 * (1 - amount),
            );
        }
    }
}

fn mix(clr1: u32, clr2: u32, amount: f32) u32 {
    if (amount > 1 or amount < 0) {
        @panic("Color mix amount must be between 0 and 1.");
    }
    const r1: f32 = @floatFromInt(clr1 & 0xFF);
    const g1: f32 = @floatFromInt((clr1 >> 8) & 0xFF);
    const b1: f32 = @floatFromInt((clr1 >> 16) & 0xFF);

    const r2: f32 = @floatFromInt(clr2 & 0xFF);
    const g2: f32 = @floatFromInt((clr2 >> 8) & 0xFF);
    const b2: f32 = @floatFromInt((clr2 >> 16) & 0xFF);

    const r: u8 = @intFromFloat(r2 * (1 - amount) + r1 * amount);
    const g: u8 = @intFromFloat(g2 * (1 - amount) + g1 * amount);
    const b: u8 = @intFromFloat(b2 * (1 - amount) + b1 * amount);

    return rgb(r, g, b);
}

fn draw_point(x: i32, y: i32, color: u32, z_pos: f64) void {
    const mapped_x = x + CENTER_X;
    const mapped_y = y + CENTER_Y;
    const out_of_canvas =
        mapped_x < 0 or mapped_x > WIDTH - 1 or mapped_y < 0 or mapped_y > HEIGHT - 1;
    const index: usize = @intCast(mapped_y * WIDTH + mapped_x);
    const point_is_behind = zbuffer[index] > z_pos;
    if (out_of_canvas or point_is_behind) return;
    zbuffer[index] = z_pos;
    pixels[index] = color;
}

fn apply_projection_mat(p: Vec3, proj: [2]Vec3) Vec2 {
    return .{
        p[0] * proj[0][0] + p[1] * proj[0][1] + p[2] * proj[0][2],
        p[0] * proj[1][0] + p[1] * proj[1][1] + p[2] * proj[1][2],
    };
}

fn apply_rotation_mat(p: Vec3, rot: [3]Vec3) Vec3 {
    return .{
        p[0] * rot[0][0] + p[1] * rot[0][1] + p[2] * rot[0][2],
        p[0] * rot[1][0] + p[1] * rot[1][1] + p[2] * rot[1][2],
        p[0] * rot[2][0] + p[1] * rot[2][1] + p[2] * rot[2][2],
    };
}

export fn get_width() u32 {
    return WIDTH;
}

export fn get_height() u32 {
    return HEIGHT;
}

export fn set_angle_x(val: f64) void {
    angle_x = val;
}

export fn get_angle_x() f64 {
    return angle_x;
}

export fn set_angle_y(val: f64) void {
    angle_y = val;
}

export fn get_angle_y() f64 {
    return angle_y;
}

export fn set_angle_z(val: f64) void {
    angle_z = val;
}

export fn get_angle_z() f64 {
    return angle_z;
}

export fn set_camera_distance(val: f64) void {
    camera_distance = val;
}

export fn get_camera_distance() f64 {
    return camera_distance;
}

export fn get_pixels_buf() *anyopaque {
    return &pixels;
}

export fn render() void {
    @memset(&zbuffer, -10);
    fill(rgb(20, 20, 20));

    const rot_mat_x: [3]Vec3 = .{
        .{ 1, 0, 0 },
        .{ 0, @cos(angle_x), -@sin(angle_x) },
        .{ 0, @sin(angle_x), @cos(angle_x) },
    };
    const rot_mat_y: [3]Vec3 = .{
        .{ @cos(angle_y), 0, -@sin(angle_y) },
        .{ 0, 1, 0 },
        .{ @sin(angle_y), 0, @cos(angle_y) },
    };
    const rot_mat_z: [3]Vec3 = .{
        .{ @cos(angle_z), -@sin(angle_z), 0 },
        .{ @sin(angle_z), @cos(angle_z), 0 },
        .{ 0, 0, 1 },
    };

    var processed_points: [POINTS.len]Vec2 = undefined;
    var processed_points_z_pos: [POINTS.len]f64 = undefined;

    // 3D points to 2D points process
    for (0..POINTS.len) |i| {
        var point: Vec3 = POINTS[i];
        point = apply_rotation_mat(point, rot_mat_x);
        point = apply_rotation_mat(point, rot_mat_y);
        point = apply_rotation_mat(point, rot_mat_z);

        const z = 1 / (camera_distance - point[2]);
        const proj_mat = .{
            .{ z, 0, 0 },
            .{ 0, z, 0 },
        };
        const projected = apply_projection_mat(point, proj_mat);
        processed_points[i] = projected * @as(Vec2, @splat(FINAL_SCALE));
        processed_points_z_pos[i] = point[2];
    }

    // Rasterization of 2D points
    for (LINES) |line| {
        const a = processed_points[line[0]];
        const a_color = POINT_COLORS[line[0]];
        const a_z_pos = processed_points_z_pos[line[0]];
        const b = processed_points[line[1]];
        const b_color = POINT_COLORS[line[1]];
        const b_z_pos = processed_points_z_pos[line[1]];

        draw_line(
            @intFromFloat(a[0]),
            @intFromFloat(a[1]),
            a_z_pos,
            a_color,
            @intFromFloat(b[0]),
            @intFromFloat(b[1]),
            b_z_pos,
            b_color,
        );
    }
}

extern "env" fn log(n: f64) void;
