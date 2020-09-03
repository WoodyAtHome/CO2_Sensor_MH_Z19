const std = @import("std");
//const builtin = @import("builtin");

const c = @cImport({
    // siehe https://www.cmrr.umn.edu/~strupp/serial.html
    @cInclude("stdio.h"); // Standard input/output definitions
    @cInclude("string.h"); // String function definitions
    @cInclude("unistd.h"); // UNIX standard function definitions
    @cInclude("fcntl.h"); // File control definitions
    @cInclude("errno.h"); // Error number definitions
    @cInclude("termios.h"); // POSIX terminal control definitions
});

pub const Port = struct {
    const Self = @This();

    pub const ReadWriteError = error{ NotOpen, NotAvailable, BufferOverflow, PortRemoved, Other };
    pub const OpenError = error{NotAvailable};

    pub const Parity = enum { None, Even, Odd };
    pub const DataBits = enum(c_uint) { B5 = c.CS5, B6 = c.CS6, B7 = c.CS7, B8 = c.CS8 };
    pub const StopBits = enum { S1_0, S1_5, S2_0 };
    pub const Baudrate = enum(c_uint) {
        B1200 = c.B1200,
        B2400 = c.B2400,
        B9600 = c.B9600,
        B19200 = c.B19200,
        B38400 = c.B38400,
        B57600 = c.B57600,
        B115200 = c.B115200,
        B230400 = c.B230400,
    };
    pub const FlowCtrl = enum { None, RtsCts, XonXoff };

    pub const Writer = std.io.Writer(*Self, ReadWriteError, writeBytes);
    pub const Reader = std.io.Reader(*Self, ReadWriteError, readBytes);

    fd: c_int = -1,
    path: [:0]const u8,

    pub fn init(path: [:0]const u8) OpenError!Port {
        const port = Port{
            .fd = c.open(path, c.O_RDWR | c.O_NOCTTY | c.O_NDELAY),
            .path = path,
        };
        if (port.fd < 0)
            return error.NotAvailable;
        // keine Ahnung warum, aber es ist hier wichtig eine Weile zu warten
        std.time.sleep(1000 * std.time.ns_per_ms);
        return port;
    }

    pub fn openAny(scanList: []const [:0]const u8) ?Port {
        for (scanList) |path| {
            if (Port.init(path)) |port| {
                return port;
            } else |_| {}
        }
        return null;
    }

    pub fn getPath(self: Self) [:0]const u8 {
        return self.path;
    }

    pub fn setCommParameter(self: Self, baud: Baudrate, databits: DataBits, parity: Parity, stopbits: StopBits, flow_ctrl: FlowCtrl) OpenError!void {
        const c_baud: c_uint = @enumToInt(baud);
        const c_databits: c_uint = @enumToInt(databits);

        var options: c.termios = undefined;
        if (c.tcgetattr(self.fd, &options) < 0)
            return error.NotAvailable;

        //        if (c.cfsetispeed(&options, c_baud) < 0)
        //            return error.NotAvailable;
        //
        //        if (c.cfsetospeed(&options, c_baud) < 0)
        //            return error.NotAvailable;
        options.c_cflag = c_baud;
        options.c_cflag |= c_databits;

        //        options.c_cflag |= (c.CLOCAL | c.CREAD);

        switch (parity) {
            .None => {},
            .Even => options.c_cflag |= c.PARENB,
            .Odd => {
                options.c_cflag |= c.PARENB;
                options.c_cflag |= c.PARODD;
            },
        }

        switch (stopbits) {
            .S1_0 => {},
            .S1_5 => return OpenError.NotAvailable,
            .S2_0 => options.c_cflag |= c.CSTOPB,
        }
        options.c_cflag |= c.CREAD;
        options.c_iflag = c.IGNPAR | c.IGNBRK;

        switch (flow_ctrl) {
            .None => options.c_cflag |= c.CLOCAL,
            .RtsCts => options.c_cflag |= c.CRTSCTS,
            .XonXoff => options.c_cflag |= c.IXON | c.IXOFF,
        }

        // RAW, not line oriented input, no echo
        options.c_oflag = 0;
        options.c_lflag = 0;
        options.c_cc[c.VTIME] = 0;
        options.c_cc[c.VMIN] = 1;

        if (c.tcsetattr(self.fd, c.TCSANOW, &options) < 0)
            return error.NotAvailable;
        if (c.tcflush(self.fd, c.TCOFLUSH) < 0)
            return error.NotAvailable;
        if (c.tcflush(self.fd, c.TCIFLUSH) < 0)
            return error.NotAvailable;

        //        const ret = std.os.fcntl(self.fd, c.F_SETFL, c.FNDELAY) catch return error.NotAvailable;
        //        if (ret < 0)
        //            return error.NotAvailable;
    }

    pub fn clearRxBuffer(self: *Self) !void {
        var buf: [64]u8 = undefined;
        while (true) {
            const len = try self.reader().read(&buf);
            if (len == 0)
                return;
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.fd >= 0) {
            _ = c.close(self.fd);
            self.fd = -1;
        }
    }

    pub fn writer(self: *Self) Writer {
        return Writer{ .context = self };
    }

    pub fn reader(self: *Self) Reader {
        return Reader{ .context = self };
    }

    fn writeBytes(self: *Self, buffer: []const u8) ReadWriteError!usize {
        if (self.fd < 0)
            return error.NotOpen;

        const len: isize = c.write(self.fd, buffer.ptr, buffer.len);
        if (len < 0) {
            const errno = std.os.errno(len);

            if (len == 0 and errno == 0)
                return error.PortRemoved; // serielle USB-Schnittstelle z.B. abgezogen

            switch (errno) {
                c.EAGAIN => return 0, // Buffer ist einfach leer und nichts zu lesen
                else => return error.Other,
            }
        }

        return @intCast(usize, len);
    }

    fn readBytes(self: *Self, buffer: []u8) ReadWriteError!usize {
        if (self.fd < 0)
            return error.NotOpen;

        const len: isize = c.read(self.fd, buffer.ptr, buffer.len);
        if (len < 0) {
            const errno = std.os.errno(len);

            switch (errno) {
                c.EAGAIN => return 0, // Buffer ist einfach leer und nichts zu lesen
                else => {
                    std.debug.warn("unknown from port err = {}, {}\n", .{ len, errno });
                    return error.Other;
                },
            }
        }

        return @intCast(usize, len);
    }
};
