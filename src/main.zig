const std = @import("std");
const serial = @import("serialport.zig");
const date = @import("localtime.zig");

pub const MH_Z19 = struct {
    const Cmd = enum(u8) {
        getConcentration = 0x86,
        calibrateZeroPoint = 0x87,
        calibrateSpanPoint = 0x88,
    };

    const Response = union(enum) {
        concentration: u16,
        invalid: void,
    };
    const msg_len = 9;
    const bcc_idx = msg_len - 1;

    const Msg = [msg_len]u8;
    const startByte = 0xff;
    const sensorNr = 0x01;
    const timeoutInMs = 1000;

    pub fn getConcentration(port: *serial.Port) !u16 {
        const req = getConcentrationReq();
        var resp: Msg = undefined;

        try port.clearRxBuffer();
        try port.writer().writeAll(&req);

        var resp_len: usize = 0;
        const start = std.time.milliTimestamp();
        while (resp_len < msg_len) {
            std.time.sleep(std.time.ns_per_ms * 10);
            resp_len += try port.reader().read(resp[resp_len..]);
            if (std.time.milliTimestamp() - start > timeoutInMs) {
                std.log.debug("read timeout: read only {} bytes: {x}", .{ resp_len, resp[0..resp_len] });
                return error.Timeout;
            }
        }
        //std.log.info("read done", .{});

        switch (decodeResponse(resp)) {
            Response.concentration => |val| return val,
            else => return error.BadResponse,
        }
    }

    fn getConcentrationReq() Msg {
        var msg = Msg{ startByte, sensorNr, @enumToInt(Cmd.getConcentration), 0, 0, 0, 0, 0, 0 };
        msg[bcc_idx] = calcCheckSum(msg);
        return msg;
    }

    fn getCalibrateZeroReq() Msg {
        var msg = Msg{ startByte, sensorNr, @enumToInt(Cmd.calibrateZeroPoint), 0, 0, 0, 0, 0, 0 };
        msg[bcc_idx] = calcCheckSum(msg);
        return msg;
    }

    fn decodeResponse(msg: Msg) Response {
        if ((msg[0] != startByte)) //or (msg[bcc_idx] != calcCheckSum(msg)))
            return Response.invalid;

        switch (msg[1]) {
            @enumToInt(Cmd.getConcentration) => return Response{ .concentration = std.mem.readIntBig(u16, msg[2..4]) },
            else => return Response.invalid,
        }
    }

    fn calcCheckSum(msg: Msg) u8 {
        var sum: u8 = 0;
        for (msg[1..bcc_idx]) |val| {
            sum +%= val;
        }
        sum = ~sum;
        sum +%= 1;
        return sum;
    }
};

pub fn main() anyerror!void {
    const port_names = &[_][:0]const u8{ "/dev/ttyUSB0", "/dev/ttyUSB1" };
    var port = serial.Port.openAny(port_names) orelse {
        for (port_names) |name| {
            std.log.err("{}: not avaiable", .{name});
        }
        return;
    };
    defer port.deinit();
    std.log.info("using port {}", .{port.getPath()});

    try port.setCommParameter(.B9600, .None, .S1_0);

    const start = std.time.timestamp();
    //while (std.time.timestamp() - start < 10){
    while (true) {
        const co2: u16 = MH_Z19.getConcentration(&port) catch |err| {
            std.log.err("MH_Z19.getConcentration = {}", .{err});
            continue;
        };
        date.printNowLocal();
        std.log.info(": CO2 conentration = {}", .{co2});
        std.time.sleep(std.time.ns_per_s * 2);
    }
}

test "MH_Z19" {
    std.testing.expectEqual(MH_Z19.Msg{ 0xff, 0x01, 0x86, 0, 0, 0, 0, 0, 0x79 }, MH_Z19.getConcentrationReq());
    std.testing.expectEqual(MH_Z19.Response{ .concentration = 0x5678 }, MH_Z19.decodeResponse(MH_Z19.Msg{ 0xff, 0x86, 0x56, 0x78, 0, 0, 0, 0, 172 }));
}
