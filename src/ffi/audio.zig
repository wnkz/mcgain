const std = @import("std");
const c = @cImport({
    @cInclude("CoreAudio/CoreAudio.h");
    @cInclude("AudioToolbox/AudioToolbox.h");
});

pub const AudioDevicePropertyScope = enum(u32) {
    input = c.kAudioDevicePropertyScopeInput,
    output = c.kAudioDevicePropertyScopeOutput,
};

pub const AudioDeviceVolumeSelector = enum(u32) {
    scalar = c.kAudioDevicePropertyVolumeScalar,
    decibels = c.kAudioDevicePropertyVolumeDecibels,
};

pub fn getAudioDevicesCount() !u32 {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioHardwarePropertyDevices,
        .mScope = c.kAudioObjectPropertyScopeGlobal,
        .mElement = c.kAudioObjectPropertyElementMaster,
    };
    var size: u32 = 0;

    try getPropertyDataSize(c.kAudioObjectSystemObject, &address, &size);
    return size / @sizeOf(c.AudioDeviceID);
}

pub fn getAudioDeviceName(allocator: std.mem.Allocator, id: u32) ![]u8 {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioDevicePropertyDeviceName,
        .mScope = c.kAudioObjectPropertyScopeGlobal,
        .mElement = c.kAudioObjectPropertyElementMaster,
    };

    var buffer: [256]u8 = undefined;
    var size: u32 = buffer.len;

    getPropertyData(id, &address, &size, &buffer) catch {
        return error.FailedToGetPropertyDeviceName;
    };
    return try allocator.dupe(u8, buffer[0 .. size - 1]);
}

pub fn getAudioDeviceIDs(allocator: std.mem.Allocator) ![]u32 {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioHardwarePropertyDevices,
        .mScope = c.kAudioObjectPropertyScopeGlobal,
        .mElement = c.kAudioObjectPropertyElementMaster,
    };
    const device_n = try getAudioDevicesCount();
    const device_ids = try allocator.alloc(c.AudioDeviceID, device_n);
    var size = device_n * @sizeOf(c.AudioDeviceID);
    try getPropertyData(c.kAudioObjectSystemObject, &address, &size, device_ids.ptr);
    return device_ids;
}

pub fn getAudioDeviceChannelsCount(id: u32, scope: AudioDevicePropertyScope) !u32 {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioDevicePropertyStreamConfiguration,
        .mScope = @intFromEnum(scope),
        .mElement = c.kAudioObjectPropertyElementMaster,
    };
    var size: u32 = 0;
    try getPropertyDataSize(id, &address, &size);

    var buffer_list = c.AudioBufferList{};
    try getPropertyData(id, &address, &size, &buffer_list);

    var channels: u32 = 0;
    for (0..buffer_list.mNumberBuffers) |i| {
        channels += buffer_list.mBuffers[i].mNumberChannels;
    }

    return channels;
}

pub fn getVolume(
    id: u32,
    selector: AudioDeviceVolumeSelector,
    scope: AudioDevicePropertyScope,
    channel: ?u32,
) ?f32 {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = @intFromEnum(selector),
        .mScope = @intFromEnum(scope),
        .mElement = channel orelse c.kAudioObjectPropertyElementMain,
    };

    var volume: f32 = 0;
    var size: u32 = @sizeOf(f32);

    if (hasProperty(id, &address)) {
        if (getPropertyData(id, &address, &size, &volume)) |_| {
            return volume;
        } else |_| {
            return null;
        }
    } else {
        return null;
    }
}

pub fn setVolume(
    id: u32,
    selector: AudioDeviceVolumeSelector,
    scope: AudioDevicePropertyScope,
    volume: f32,
    channel: ?u32,
) !void {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = @intFromEnum(selector),
        .mScope = @intFromEnum(scope),
        .mElement = channel orelse c.kAudioObjectPropertyElementMain,
    };

    const size: u32 = @sizeOf(f32);

    if (hasProperty(id, &address)) {
        try setPropertyData(id, &address, size, @constCast(&volume));
    }
}

fn hasVolumeScalarProperty(id: u32, scope: AudioDevicePropertyScope, channel: ?u32) bool {
    var address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioDevicePropertyVolumeScalar,
        .mScope = @intFromEnum(scope),
        .mElement = channel or c.kAudioObjectPropertyElementMaster,
    };
    return hasProperty(id, &address);
}

fn hasProperty(id: c.AudioObjectID, address: *c.AudioObjectPropertyAddress) bool {
    const ret = c.AudioObjectHasProperty(id, address);
    return ret != 0;
}

fn setPropertyData(
    object_id: c.AudioObjectID,
    address: *c.AudioObjectPropertyAddress,
    size: u32,
    data: *anyopaque,
) !void {
    const status: c.OSStatus = c.AudioObjectSetPropertyData(
        object_id,
        address,
        0,
        null,
        size,
        data,
    );

    std.log.debug("c.AudioObjectSetPropertyData: id={d}, address={any}, size={d}, data={any}", .{ object_id, address, size, data });

    if (status != c.noErr) {
        return error.FailedToSetPropertyData;
    }
}

fn getPropertyData(
    object_id: c.AudioObjectID,
    address: *c.AudioObjectPropertyAddress,
    size: *u32,
    data: *anyopaque,
) !void {
    const status: c.OSStatus = c.AudioObjectGetPropertyData(
        object_id,
        address,
        0,
        null,
        size,
        data,
    );

    std.log.debug("c.AudioObjectGetPropertyData: id={d}, address={any}, size={d}, data={any}", .{ object_id, address, size.*, data });

    if (status != c.noErr) {
        return error.FailedToGetPropertyData;
    }
}

fn getPropertyDataSize(
    object_id: c.AudioObjectID,
    address: *c.AudioObjectPropertyAddress,
    size: *u32,
) !void {
    const status: c.OSStatus = c.AudioObjectGetPropertyDataSize(
        object_id,
        address,
        0,
        null,
        size,
    );

    std.log.debug("c.AudioObjectGetPropertyDataSize: id={d}, address={any}, size={d}", .{ object_id, address, size.* });

    if (status != c.noErr) {
        return error.FailedToGetPropertyDataSize;
    }
}
