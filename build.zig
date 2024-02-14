const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const exe = b.addExecutable(.{
        .name = "zig-cube",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .ReleaseSmall,
    });
    b.installArtifact(exe);

    exe.global_base = 6560;
    exe.entry = .disabled;
    exe.rdynamic = true;
    // exe.import_memory = true;
    exe.stack_size = std.wasm.page_size;

    exe.initial_memory = std.wasm.page_size * 32;
    exe.max_memory = std.wasm.page_size * 32;

    // const zmath_dep = b.dependency("zmath", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const zmath_module = zmath_dep.module("zmath");
    // exe.root_module.addImport("zmath", zmath_module);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .ReleaseSmall,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
