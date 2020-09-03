const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const MyTarget = struct {
        target: std.zig.CrossTarget,
        name: []const u8,
        run: bool = false,
        remote: bool = false,
    };

    const pc_target = MyTarget{ .target = b.standardTargetOptions(.{}), .name = "co2_pc", .run = true };
    const rpi_target = MyTarget{ .target = std.zig.CrossTarget{ .cpu_arch = .arm, .os_tag = .linux, .abi = .musleabi }, .name = "co2_rpi", .remote = true };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable(pc_target.name, "src/main.zig");
    exe.setTarget(pc_target.target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.install();

    b.default_step.dependOn(&exe.step);
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const rpi_exe = b.addExecutable(rpi_target.name, "src/main.zig");
    rpi_exe.setTarget(rpi_target.target);
    rpi_exe.setBuildMode(mode);
    rpi_exe.linkLibC();
    rpi_exe.install();

    const kill_exe_cmd = b.addSystemCommand(&[_][]const u8{ "ssh", "pi@homeserver", "killall", "-q", rpi_target.name });
    kill_exe_cmd.step.dependOn(&rpi_exe.step);

    const cmd_arg = std.fmt.allocPrint(b.allocator, "zig-cache/bin/{}", .{rpi_target.name}) catch @panic("Out of memory");
    defer b.allocator.free(cmd_arg);
    const update_exe_cmd = b.addSystemCommand(&[_][]const u8{ "scp", cmd_arg, "scp://pi@homeserver/" });

    const cmd_arg2 = std.fmt.allocPrint(b.allocator, "'nohup ./{}>>/media/co2.txt 2>&1 &'", .{rpi_target.name}) catch @panic("Out of memory");
    defer b.allocator.free(cmd_arg2);
    const start_exe_cmd = b.addSystemCommand(&[_][]const u8{ "ssh", "pi@homeserver", "bash", "-c", cmd_arg2 });
    start_exe_cmd.step.dependOn(&update_exe_cmd.step);

    var buildrpi_step = b.step("rpi", "build the rpi executable");
    buildrpi_step.dependOn(&rpi_exe.step);

    var update_step = b.step("update_rpi", "sstop & update & start the rpi executable");
    update_step.dependOn(&kill_exe_cmd.step);
    update_step.dependOn(&start_exe_cmd.step);

    var update_rpi_step = b.step("run_rpi", "update & start the rpi executable");
    update_rpi_step.dependOn(&start_exe_cmd.step);
}
