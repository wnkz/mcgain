const std = @import("std");
const mem = std.mem;

const audio = @import("ffi/audio.zig");

pub const AudioDeviceChannel = struct {
    pub const VolumeSelector = enum {
        scalar,
        decibels,
    };

    pub const Type = enum {
        input,
        output,
    };

    id: u32,
    device_id: u32,
    dtype: AudioDeviceChannel.Type,

    pub fn init(id: u32, dtype: AudioDeviceChannel.Type, device_id: u32) !AudioDeviceChannel {
        if (audio.getVolume(device_id, audio.AudioDeviceVolumeSelector.scalar, getAudioScope(dtype), id)) |_| {
            return AudioDeviceChannel{
                .id = id,
                .device_id = device_id,
                .dtype = dtype,
            };
        }
        return error.BadChannel; // TODO: find a better name
    }

    pub fn getVolume(self: *const AudioDeviceChannel, selector: AudioDeviceChannel.VolumeSelector) ?f32 {
        return audio.getVolume(
            self.device_id,
            getAudioSelector(selector),
            getAudioScope(self.dtype),
            self.id,
        );
    }

    pub fn setVolume(
        self: *const AudioDeviceChannel,
        selector: AudioDeviceChannel.VolumeSelector,
        volume: f32,
    ) !void {
        try audio.setVolume(
            self.device_id,
            getAudioSelector(selector),
            getAudioScope(self.dtype),
            volume,
            self.id,
        );
    }

    fn getAudioScope(dtype: AudioDeviceChannel.Type) audio.AudioDevicePropertyScope {
        return switch (dtype) {
            AudioDeviceChannel.Type.input => audio.AudioDevicePropertyScope.input,
            AudioDeviceChannel.Type.output => audio.AudioDevicePropertyScope.output,
        };
    }

    fn getAudioSelector(selector: AudioDeviceChannel.VolumeSelector) audio.AudioDeviceVolumeSelector {
        return switch (selector) {
            AudioDeviceChannel.VolumeSelector.scalar => audio.AudioDeviceVolumeSelector.scalar,
            AudioDeviceChannel.VolumeSelector.decibels => audio.AudioDeviceVolumeSelector.decibels,
        };
    }
};

pub const AudioDevice = struct {
    gpa: mem.Allocator,
    id: u32,
    name: []u8,
    in_channels: u32 = 0,
    out_channels: u32 = 0,
    channels_n: [2]u32 = [_]u32{ 0, 0 },
    channels: [2]std.AutoHashMap(u32, AudioDeviceChannel) = undefined,

    pub fn init(gpa: mem.Allocator, id: u32) !AudioDevice {
        var d = AudioDevice{
            .gpa = gpa,
            .id = id,
            .name = try audio.getAudioDeviceName(gpa, id),
            .in_channels = audio.getAudioDeviceChannelsCount(id, audio.AudioDevicePropertyScope.input) catch 0,
            .out_channels = audio.getAudioDeviceChannelsCount(id, audio.AudioDevicePropertyScope.output) catch 0,
            .channels_n = [_]u32{
                audio.getAudioDeviceChannelsCount(id, audio.AudioDevicePropertyScope.input) catch 0,
                audio.getAudioDeviceChannelsCount(id, audio.AudioDevicePropertyScope.output) catch 0,
            },
            .channels = [_]std.AutoHashMap(u32, AudioDeviceChannel){
                std.AutoHashMap(u32, AudioDeviceChannel).init(gpa),
                std.AutoHashMap(u32, AudioDeviceChannel).init(gpa),
            },
        };

        try d.initChannels(AudioDeviceChannel.Type.input);
        try d.initChannels(AudioDeviceChannel.Type.output);

        return d;
    }

    fn initChannels(self: *AudioDevice, dtype: AudioDeviceChannel.Type) !void {
        // NOTE: We can't really trust the number of channels so we always check 0 (Main/Master)
        try self.tryAddChannel(dtype, 0);

        var i: u32 = 1;
        while (i <= self.channels_n[@intFromEnum(dtype)]) : (i += 1) {
            try self.tryAddChannel(dtype, i);
        }
    }

    fn tryAddChannel(self: *AudioDevice, dtype: AudioDeviceChannel.Type, channel_id: u32) !void {
        if (AudioDeviceChannel.init(channel_id, dtype, self.id)) |channel| {
            try self.channels[@intFromEnum(dtype)].put(channel_id, channel);
        } else |err| switch (err) {
            error.BadChannel => {},
            else => return err,
        }
    }

    pub fn setChannelsVolume(
        self: *AudioDevice,
        volume: f32,
        dtype: AudioDeviceChannel.Type,
        selector: AudioDeviceChannel.VolumeSelector,
        channel_id: ?u32,
    ) !void {
        if (channel_id) |id| {
            try self.channels[@intFromEnum(dtype)].get(id).?.setVolume(selector, volume);
        } else {
            var iter = self.channels[@intFromEnum(dtype)].iterator();
            while (iter.next()) |entry| {
                const channel = entry.value_ptr;
                try channel.setVolume(selector, volume);
            }
        }
    }
};

pub fn getAudioDevices(alloc: mem.Allocator) !std.ArrayList(AudioDevice) {
    var devices = std.ArrayList(AudioDevice).init(alloc);
    const device_ids = try audio.getAudioDeviceIDs(alloc);
    for (device_ids) |device_id| {
        try devices.append(try AudioDevice.init(alloc, device_id));
    }
    return devices;
}
