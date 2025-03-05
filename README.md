# 🎤 mcgain

A simple command-line tool to control audio device volume levels on macOS.

> [!NOTE]
> This is my first project written in Zig. While I'm learning the language and trying to follow best practices, there might be some non-idiomatic code.

## ✨ Features

- List available audio devices
- Get volume levels for input/output channels
- Set volume levels for input/output channels
- Support for both scalar (0-1) and decibel values

## Prerequisites

- macOS (uses CoreAudio)
- Zig 0.13.0 or later

## Installation

```bash
git clone https://github.com/wnkz/mcgain.git
cd mcgain
zig build
```

The binary will be available at `zig-out/bin/mcgain`

## 🚀 Usage

### List available devices
```bash
mcgain ls
```

### Get volume levels
```bash
mcgain get-levels              # Show volume levels in scalar (0-1)
mcgain get-levels -d           # Show volume levels in decibels
mcgain get-levels -n           # Show device names
```

### Set volume levels
```bash
mcgain set-levels <device_id> <in|out> <value>      # Set volume using scalar (0-1)
mcgain set-levels -d <device_id> <in|out> <value>   # Set volume using decibels
mcgain set-levels -n "Device Name" <in|out> <value> # Set volume by device name
```

## Building from source

```bash
zig build        # Build the project
zig build run    # Build and run
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Written in [Zig](https://ziglang.org/)
- Uses macOS CoreAudio Framework
