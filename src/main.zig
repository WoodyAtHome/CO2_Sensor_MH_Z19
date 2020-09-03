const std = @import("std");
const serial = @import("serialport.zig");
const date = @import("localtime.zig");
const MH_Z19 = @import("MH_Z19.zig");

pub const log_level = std.log.Level.info;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const port_names = &[_][:0]const u8{ "/dev/ttyUSB1", "/dev/ttyUSB0" };
    var port = serial.Port.openAny(port_names) orelse {
        for (port_names) |name| {
            std.log.err("{}: not avaiable", .{name});
        }
        return;
    };
    defer port.deinit();
    std.log.info("using port {}", .{port.getPath()});

    try port.setCommParameter(.B9600, .B8, .None, .S1_0, .None);

    // nach dem Einschalten werden 4 Bytes gesendet,  ff38a3e4, die müssen ggf. erst gelesen werden
    // der Delay ist unklar warum der hier rein muss
    std.time.sleep(std.time.ns_per_ms * 500);
    try port.clearRxBuffer();

    const start = std.time.timestamp();
    //while (std.time.timestamp() - start < 3600) {
    while (true) {
        date.printNowLocal();
        if (MH_Z19.getConcentration(&port)) |co2| {
            std.log.info(": CO2 conentration = {} ppm", .{co2});
        } else |err| {
            std.log.err(": MH_Z19.getConcentration = {}", .{err});
        }
        std.time.sleep(std.time.ns_per_s * 10);
    }
}

test "MH_Z19" {
    std.testing.expectEqual(MH_Z19.Msg{ 0xff, 0x01, 0x86, 0, 0, 0, 0, 0, 0x79 }, MH_Z19.getConcentrationReq());
    std.testing.expectEqual(MH_Z19.Response{ .concentration = 0x5678 }, MH_Z19.decodeResponse(MH_Z19.Msg{ 0xff, 0x86, 0x56, 0x78, 0, 0, 0, 0, 172 }));
}
