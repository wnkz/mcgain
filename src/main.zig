const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const mem = std.mem;
const process = std.process;

const audio = @import("audio.zig");

const AudioDevice = audio.AudioDevice;
const AudioDeviceChannel = audio.AudioDeviceChannel;
const getAudioDevices = audio.getAudioDevices;

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    process.exit(1);
}

const usage =
    \\Usage: mcgain [command] [options]
    \\
    \\Commands:
    \\
    \\  ls               List available audio devices
    \\  get-levels       List volume levels of available devices
    \\  set-levels       Set volume levels of a device
    \\
    \\  help             Print this help and exit
    \\
    \\General Options:
    \\
    \\  -h, --help       Print command-specific usage
    \\
;

fn cmdLs(
    gpa: mem.Allocator,
    arena: mem.Allocator,
    args: []const []const u8,
) !void {
    _ = gpa;

    const cmd_usage =
        \\Usage: mcgain ls [options]
        \\
        \\Options:
        \\
        \\  -h, --help       Print command-specific usage
        \\
    ;

    const sep: u8 = '\t';

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = io.getStdOut().writer();
                try stdout.writeAll(cmd_usage);
                return process.cleanExit();
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else {
            fatal("unexpected extra parameter: '{s}'", .{arg});
        }
    }

    const devices = try getAudioDevices(arena);
    const stdout = io.getStdOut().writer();
    for (devices.items) |*device| {
        try stdout.print("{d}", .{device.id});
        try stdout.print("{c}", .{sep});
        try stdout.print("{d}:ins", .{device.channels_n[@intFromEnum(AudioDeviceChannel.Type.input)]});
        try stdout.print("{c}", .{sep});
        try stdout.print("{d}:outs", .{device.channels_n[@intFromEnum(AudioDeviceChannel.Type.output)]});
        try stdout.print("{c}", .{sep});
        try stdout.print("{s}\n", .{device.name});
    }
}

fn cmdGetLevels(
    gpa: mem.Allocator,
    arena: mem.Allocator,
    args: []const []const u8,
) !void {
    _ = gpa;

    const cmd_usage =
        \\Usage: mcgain get-levels [options]
        \\
        \\Options:
        \\
        \\  -n, --name       Show device name
        \\  -d, --dB         Print volume in dB instead of scalar
        \\  -h, --help       Print command-specific usage
        \\
    ;

    const sep: u8 = '\t';
    var show_name: bool = false;
    var use_decibels: bool = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-n") or mem.eql(u8, arg, "--name")) {
                show_name = true;
            } else if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--dB")) {
                use_decibels = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = io.getStdOut().writer();
                try stdout.writeAll(cmd_usage);
                return process.cleanExit();
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else {
            fatal("unexpected extra parameter: '{s}'", .{arg});
        }
    }

    const selector = if (use_decibels) AudioDeviceChannel.VolumeSelector.decibels else AudioDeviceChannel.VolumeSelector.scalar;
    const stdout = io.getStdOut().writer();
    const devices = try getAudioDevices(arena);

    for (devices.items) |*device| {
        for (device.channels) |channels| {
            var iter = channels.iterator();
            while (iter.next()) |entry| {
                const channel = entry.value_ptr;
                const channel_prefix = switch (channel.dtype) {
                    AudioDeviceChannel.Type.input => "in",
                    AudioDeviceChannel.Type.output => "out",
                };
                try stdout.print("{d}", .{device.id});
                try stdout.print("{c}", .{sep});
                try stdout.print("{s}{d}", .{ channel_prefix, channel.id });
                try stdout.print("{c}", .{sep});
                try stdout.print("{d}{s}", .{ channel.getVolume(selector).?, if (use_decibels) "dB" else "" });
                if (show_name) {
                    try stdout.print("{c}", .{sep});
                    try stdout.print("{s}", .{device.name});
                }
                try stdout.print("\n", .{});
            }
        }
    }
}

fn cmdSetLevels(
    gpa: mem.Allocator,
    arena: mem.Allocator,
    args: []const []const u8,
) !void {
    _ = gpa;

    const cmd_usage =
        \\Usage: mcgain set-levels device scope value [options]
        \\
        \\Arguments:
        \\
        \\  device           Device ID or name if search by name is enabled (see options)
        \\  scope            in || out
        \\  value            Volume as scalar (0-1) or dB if enabled (see options)
        \\
        \\Options:
        \\
        \\  -n, --name       Search by device name
        \\  -d, --dB         Set volume in dB instead of scalar
        \\  -h, --help       Print command-specific usage
        \\
    ;

    var eoo: bool = false;
    var search_by_name: bool = false;
    var use_decibels: bool = false;
    var arg_device: ?[]const u8 = null;
    var arg_scope: ?[]const u8 = null;
    var arg_value: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (mem.eql(u8, arg, "--")) {
            eoo = true;
            continue;
        }
        if (mem.startsWith(u8, arg, "-") and !eoo) {
            if (mem.eql(u8, arg, "-n") or mem.eql(u8, arg, "--name")) {
                search_by_name = true;
            } else if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--dB")) {
                use_decibels = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = io.getStdOut().writer();
                try stdout.writeAll(cmd_usage);
                return process.cleanExit();
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else if (arg_device == null) {
            arg_device = arg;
        } else if (arg_scope == null) {
            arg_scope = arg;
        } else if (arg_value == null) {
            arg_value = arg;
        } else {
            fatal("unexpected extra parameter: '{s}'", .{arg});
        }
    }

    if (arg_device == null or arg_scope == null or arg_value == null) {
        fatal("missing required argument, check usage", .{});
    }

    const scope = blk: {
        const scope = arg_scope orelse fatal("missing required argument: scope", .{});
        if (mem.eql(u8, scope, "in")) {
            break :blk AudioDeviceChannel.Type.input;
        } else if (mem.eql(u8, scope, "out")) {
            break :blk AudioDeviceChannel.Type.output;
        } else {
            fatal("invalid scope: '{s}'", .{scope});
        }
        unreachable;
    };

    const value = blk: {
        const value = arg_value orelse fatal("missing required argument: value", .{});
        break :blk std.fmt.parseFloat(f32, value) catch {
            fatal("invalid value: {s}", .{value});
        };
    };

    const selector = switch (use_decibels) {
        true => AudioDeviceChannel.VolumeSelector.decibels,
        false => AudioDeviceChannel.VolumeSelector.scalar,
    };

    const s_device = arg_device orelse fatal("missing required argument: device", .{});

    if (search_by_name) {
        const devices = try getAudioDevices(arena);
        for (devices.items) |*device| {
            if (mem.eql(u8, device.name, s_device)) {
                try device.setChannelsVolume(
                    value,
                    scope,
                    selector,
                    null,
                );
            }
        }
    } else {
        const device_id = std.fmt.parseInt(u32, s_device, 10) catch {
            fatal("invalid device ID: {s}", .{s_device});
        };
        var device = try AudioDevice.init(arena, device_id);
        try device.setChannelsVolume(
            value,
            scope,
            selector,
            null,
        );
    }
}

var debug_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.c_allocator, false }, // TODO: zig>=0.14 std.heap.smp_allocator
        };
    };

    defer if (is_debug) {
        std.debug.assert(debug_allocator.deinit() == .ok);
    };

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();

    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len <= 1) {
        std.log.info("{s}", .{usage});
        fatal("expected command argument", .{});
    }

    const cmd = args[1];
    const cmd_args = args[2..];

    if (mem.eql(u8, cmd, "ls")) {
        return cmdLs(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "get-levels")) {
        return cmdGetLevels(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "set-levels")) {
        return cmdSetLevels(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "-h") or mem.eql(u8, cmd, "--help")) {
        try io.getStdOut().writeAll(usage);
        return process.cleanExit();
    } else {
        std.log.info("{s}", .{usage});
        fatal("unknown command: {s}", .{args[1]});
    }
}
