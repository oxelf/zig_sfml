const std = @import("std");

fn contains(slice: []const u8, item: []const u8) bool {
    return std.mem.indexOf(u8, slice, item) != null;
}

fn sources(gpa: std.mem.Allocator, dir_path: []const u8) ![]const []const u8 {
    var srcs = try std.ArrayList([]const u8).initCapacity(gpa, 128);
    defer srcs.deinit(gpa);

    const dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });

    var walk = try dir.walk(gpa);
    defer walk.deinit();
    while (try walk.next()) |entry| {
        if (entry.kind == .file) {
            if (std.mem.endsWith(u8, entry.basename, ".cpp") or std.mem.endsWith(u8, entry.basename, ".c")) {
                const sentinel_removed: []const u8 = gpa.dupe(u8, entry.path[0..entry.path.len]) catch entry.path;
                try srcs.append(gpa, sentinel_removed);
            }
        }
    }

    return try srcs.toOwnedSlice(gpa);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sysroot = b.option([]const u8, "sysroot", "Path to sysroot");

    if (target.result.os.tag == .ios and sysroot == null) {
        @panic("sysroot is required when targeting iOS");
    }

    b.sysroot = sysroot;

    const gpa = b.allocator;

    const upstream = b.dependency("sfml", .{});

    const network_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const libnetwork = b.addLibrary(.{
        .name = "sfml-network",
        .linkage = .static,
        .root_module = network_mod,
    });
    network_mod.addIncludePath(upstream.path("include"));
    network_mod.addIncludePath(upstream.path("src"));

    network_mod.addCMacro("SFML_STATIC", "1");
    //network_mod.addCMacro("SFML_NETWORK_EXPORTS", "1");

    network_mod.addCSourceFiles(.{
        .root = upstream.path("src/SFML/Network"),
        .files = &[_][]const u8{
            "Ftp.cpp",
            "Http.cpp",
            "IpAddress.cpp",
            "Packet.cpp",
            "Socket.cpp",
            "SocketSelector.cpp",
            "TcpListener.cpp",
            "TcpSocket.cpp",
            "UdpSocket.cpp",
        },
    });
    if (target.result.os.tag == .windows) {
        network_mod.addCSourceFile(.{
            .file = upstream.path("src/SFML/Network/Win32/SocketImpl.cpp"),
        });
    } else {
        network_mod.addCSourceFile(.{
            .file = upstream.path("src/SFML/Network/Unix/SocketImpl.cpp"),
        });
    }

    const audio_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const libaudio = b.addLibrary(.{
        .name = "sfml-audio",
        .linkage = .static,
        .root_module = audio_mod,
    });
    audio_mod.addIncludePath(upstream.path("include"));
    audio_mod.addIncludePath(upstream.path("src"));
    audio_mod.addIncludePath(upstream.path("extlibs/headers/miniaudio"));
    audio_mod.addIncludePath(upstream.path("extlibs/headers/minimp3"));

    audio_mod.addCMacro("SFML_STATIC", "1");
    audio_mod.addCMacro("FLAC_NO_DLL", "1");
    audio_mod.addCMacro("FLAC__NO_DLL", "1");

    if (target.result.os.tag == .ios and target.result.abi == .simulator) {
        audio_mod.addCMacro("MA_NO_AVX2", "1");
        audio_mod.addCMacro("MA_NO_NEON", "1");
        audio_mod.addCMacro("MA_NO_SSE2", "1");
        audio_mod.addCMacro("MINIMP3_NO_SIMD", "1");
        audio_mod.addCMacro("MA_DR_MP3_NO_SIMD", "1");
        audio_mod.addCMacro("MA_DR_FLAC_NO_SIMD", "1");
        audio_mod.addCMacro("MINIMP3_NO_SSE", "1");
    }

    //audio_mod.addCMacro("SFML_AUDIO_EXPORTS", "1");
    audio_mod.addCMacro("SFML_IS_BIG_ENDIAN", "1");
    audio_mod.addCMacro("MA_USE_STDINT", "1");

    const flac = b.dependency(
        "flac",
        .{ .target = target, .optimize = optimize },
    );
    audio_mod.linkLibrary(flac.artifact("flac"));
    audio_mod.addIncludePath(flac.path("include"));

    const vorbis = b.dependency(
        "vorbis",
        .{ .target = target, .optimize = optimize },
    );

    audio_mod.linkLibrary(vorbis.artifact("vorbis"));
    audio_mod.addIncludePath(vorbis.path("include"));

    if (target.result.os.tag == .ios) {
        // audio_mod.addCSourceFile(.{
        //     .file = upstream.path("extlibs/headers/miniaudio/miniaudio.c"),
        //     .language = .objective_cpp,
        //     .flags = &[_][]const u8{
        //         "-DMA_NO_NEON=1",
        //         "-DMA_NO_AVX2=1",
        //         "-DMA_NO_SSE2=1",
        //         "-DMINIAUDIO_NO_INTRINSICS=1",
        //         "-DMA_NO_MP3=1",
        //         "-DMA_USE_STDINT=1",
        //         "-DSFML_STATIC=1",
        //     },
        // });
        audio_mod.addCSourceFile(.{ .file = upstream.path("src/SFML/Audio/Miniaudio.cpp"), .language = .objective_cpp });
        // audio_mod.addCSourceFile(.{ .file = upstream.path("src/SFML/Main/MainiOS.mm"), .language = .objective_cpp });
        //
        // audio_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/Frameworks" }) });
        // audio_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/SubFrameworks" }) });
        // audio_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/usr/include" }) });
        // audio_mod.linkFramework("UIKit", .{});
        // audio_mod.linkFramework("UIUtilities", .{});
        // audio_mod.linkFramework("QuartzCore", .{});
        // audio_mod.linkFramework("CoreGraphics", .{});
        // audio_mod.linkFramework("CoreMotion", .{});
        // audio_mod.linkFramework("Foundation", .{});
        // audio_mod.linkFramework("OpenGLES", .{});
    } else {
        audio_mod.addCSourceFile(.{ .file = upstream.path("extlibs/headers/miniaudio/miniaudio.c"), .language = .c });
        audio_mod.addCSourceFile(.{ .file = upstream.path("src/SFML/Audio/Miniaudio.cpp"), .language = .cpp });
    }

    audio_mod.addCSourceFiles(.{
        .root = upstream.path("src/SFML/Audio"),
        .files = &[_][]const u8{
            "AudioDevice.cpp",
            "AudioResource.cpp",
            "InputSoundFile.cpp",
            "Listener.cpp",
            "MiniaudioUtils.cpp",
            "Music.cpp",
            "OutputSoundFIle.cpp",
            "PlaybackDevice.cpp",
            "Sound.cpp",
            "SoundBuffer.cpp",
            "SoundBufferRecorder.cpp",
            "SoundFileFactory.cpp",
            "SoundFileReaderFlac.cpp",
            "SoundFileReaderMp3.cpp",
            "SoundFileReaderOgg.cpp",
            "SoundFileReaderWav.cpp",
            "SoundFileWriterFlac.cpp",
            "SoundFileWriterOgg.cpp",
            "SoundFileWriterWav.cpp",
            "SoundRecorder.cpp",
            "SoundSource.cpp",
            "SoundStream.cpp",
        },
    });

    const graphics_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const libgraphics = b.addLibrary(.{
        .name = "sfml-graphics",
        .linkage = .static,
        .root_module = graphics_mod,
    });

    const freetype = b.dependency(
        "freetype",
        .{ .target = target, .optimize = optimize },
    );
    graphics_mod.linkLibrary(freetype.artifact("freetype"));
    graphics_mod.addIncludePath(freetype.path("include"));

    const sheenbidi = b.dependency(
        "sheenbidi",
        .{ .target = target, .optimize = optimize },
    );

    graphics_mod.linkLibrary(sheenbidi.artifact("sheenbidi"));
    graphics_mod.addIncludePath(sheenbidi.path("include"));

    const harfbuzz = b.dependency(
        "harfbuzz",
        .{ .target = target, .optimize = optimize },
    );

    graphics_mod.linkLibrary(harfbuzz.artifact("harfbuzz"));
    graphics_mod.addIncludePath(harfbuzz.path("include"));

    graphics_mod.addIncludePath(upstream.path("include"));
    graphics_mod.addIncludePath(upstream.path("src"));
    graphics_mod.addIncludePath(upstream.path("extlibs/headers/glad/include"));
    graphics_mod.addIncludePath(upstream.path("extlibs/headers/stb_image/"));
    graphics_mod.addIncludePath(upstream.path("extlibs/headers/qoi/"));

    graphics_mod.addCMacro("SFML_STATIC", "1");
    //graphics_mod.addCMacro("SFML_GRAPHICS_EXPORTS", "1");

    graphics_mod.addCSourceFiles(.{
        .root = upstream.path("src/SFML/Graphics"),
        .files = try sources(
            gpa,
            upstream.path("src/SFML/Graphics").getPath(b),
        ),
    });

    const system_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const libsystem = b.addLibrary(.{
        .name = "sfml-system",
        .linkage = .static,
        .root_module = system_mod,
    });
    system_mod.addIncludePath(upstream.path("include"));
    system_mod.addIncludePath(upstream.path("src"));
    system_mod.addIncludePath(upstream.path("extlibs/headers/cpp-unicodelib"));

    system_mod.addCMacro("SFML_STATIC", "1");
    //system_mod.addCMacro("SFML_SYSTEM_EXPORTS", "1");

    system_mod.addCSourceFiles(.{
        .root = upstream.path("src/SFML/System"),
        .files = &[_][]const u8{
            "Clock.cpp",
            "Err.cpp",
            "FileInputStream.cpp",
            "MemoryInputStream.cpp",
            "Sleep.cpp",
            "String.cpp",
            "Utils.cpp",
            "Vector2.cpp",
            "Vector3.cpp",
        },
    });
    if (target.result.os.tag == .windows) {
        system_mod.addCSourceFile(.{
            .file = upstream.path("src/SFML/System/Win32/SleepImpl.cpp"),
        });
    }
    if (target.result.abi.isAndroid()) {
        system_mod.addCSourceFiles(.{
            .root = upstream.path("src/SFML/System/Android"),
            .files = try sources(gpa, upstream.path("src/SFML/System/Android").getPath(b)),
        });
    }
    if (target.result.os.tag != .windows) {
        system_mod.addCSourceFile(.{
            .file = upstream.path("src/SFML/System/Unix/SleepImpl.cpp"),
        });
    }

    const window_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });
    const libwindow = b.addLibrary(.{
        .name = "sfml-window",
        .linkage = .static,
        .root_module = window_mod,
    });
    window_mod.addIncludePath(upstream.path("include"));
    window_mod.addIncludePath(upstream.path("src"));
    window_mod.addIncludePath(upstream.path("extlibs/headers/glad/include"));

    window_mod.addCMacro("SFML_STATIC", "1");
    //window_mod.addCMacro("SFML_WINDOW_EXPORTS", "1");

    window_mod.addCSourceFiles(.{
        .root = upstream.path("src/SFML/Window"),
        .files = &[_][]const u8{
            "Clipboard.cpp",
            "Context.cpp",
            "Cursor.cpp",
            "EGLCheck.cpp",
            "EglContext.cpp",
            "GlContext.cpp",
            "GlResource.cpp",
            "Joystick.cpp",
            "JoystickManager.cpp",
            "Keyboard.cpp",
            "Mouse.cpp",
            "Sensor.cpp",
            "SensorManager.cpp",
            "Touch.cpp",
            "VideoMode.cpp",
            "Vulkan.cpp",
            "Window.cpp",
            "WindowBase.cpp",
            "WindowImpl.cpp",
        },
    });
    if (target.result.abi.isAndroid()) {
        window_mod.addCSourceFiles(.{
            .root = upstream.path("src/SFML/Window/Android"),
            .files = try sources(gpa, upstream.path("src/SFML/Window/Android").getPath(b)),
        });
    } else {
        switch (target.result.os.tag) {
            .windows => {
                window_mod.linkSystemLibrary("opengl32", .{});
                window_mod.linkSystemLibrary("gdi32", .{});
                window_mod.linkSystemLibrary("winmm", .{});
                window_mod.linkSystemLibrary("dinput8", .{}); // optional
                window_mod.addCSourceFiles(.{
                    .root = upstream.path("src/SFML/Window/Win32"),
                    .files = try sources(gpa, upstream.path("src/SFML/Window/Win32").getPath(b)),
                });

                window_mod.addIncludePath(upstream.path("extlibs/headers/Vulkan"));
            },
            .netbsd, .freebsd, .openbsd, .linux => {
                window_mod.addCSourceFiles(.{
                    .root = upstream.path("src/SFML/Window/Unix"),
                    .files = try sources(gpa, upstream.path("src/SFML/Window/Unix").getPath(b)),
                });
                window_mod.addIncludePath(b.path("x11-headers/"));
                window_mod.linkSystemLibrary("X11", .{ .preferred_link_mode = .dynamic });
                window_mod.linkSystemLibrary("Xrandr", .{ .preferred_link_mode = .dynamic });
                window_mod.linkSystemLibrary("Xcursor", .{ .preferred_link_mode = .dynamic });
                window_mod.linkSystemLibrary("Xi", .{ .preferred_link_mode = .dynamic });
                window_mod.linkSystemLibrary("udev", .{ .preferred_link_mode = .dynamic });
                window_mod.linkSystemLibrary("dl", .{ .preferred_link_mode = .dynamic });
                window_mod.addIncludePath(b.path("libudev"));
                window_mod.addIncludePath(upstream.path("extlibs/headers/Vulkan"));
            },
            .macos => {
                window_mod.linkFramework("Cocoa", .{});
                window_mod.linkFramework("IOKit", .{});
                window_mod.linkFramework("CoreFoundation", .{});
                window_mod.linkFramework("CoreGraphics", .{});
                window_mod.linkFramework("Carbon", .{});
                window_mod.linkFramework("ApplicationServices", .{});
                window_mod.addCSourceFiles(.{
                    .root = upstream.path("src/SFML/Window/macOS"),
                    .files = try sources(gpa, upstream.path("src/SFML/Window/macOS").getPath(b)),
                });
                window_mod.addCSourceFiles(.{
                    .root = upstream.path("src/SFML/Window/macOS"),
                    .files = &[_][]const u8{
                        "cg_sf_conversion.mm",
                        "CursorImpl.mm",
                        "ClipboardImpl.mm",
                        "InputImpl.mm",
                        "HIDInputManager.mm",
                        "NSImage+raw.mm",
                        "SFApplication.m",
                        "SFApplicationDelegate.m",
                        "SFContext.mm",
                        "SFKeyboardModifiersHelper.mm",
                        "SFOpenGLView.mm",
                        "SFOpenGLView+keyboard.mm",
                        "SFOpenGLView+mouse.mm",
                        "SFSilentResponder.m",
                        "SFWindow.m",
                        "SFWindowController.mm",
                        "SFViewController.mm",
                        "WindowImplCocoa.mm",
                        "AutoReleasePoolWrapper.mm",
                    },

                    .flags = &.{ "-x", "objective-c++" },
                });
            },
            .ios => {
                // window_mod.addCSourceFiles(.{
                //     .root = upstream.path("src/SFML/Window/iOS"),
                //     .files = try sources(gpa, upstream.path("src/SFML/Window/iOS").getPath(b)),
                // });

                window_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/Frameworks" }) });
                window_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/SubFrameworks" }) });
                window_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/usr/include" }) });
                window_mod.linkFramework("UIKit", .{});
                window_mod.linkFramework("UIUtilities", .{});
                window_mod.linkFramework("QuartzCore", .{});
                window_mod.linkFramework("CoreGraphics", .{});
                window_mod.linkFramework("CoreMotion", .{});
                window_mod.linkFramework("Foundation", .{});
                window_mod.linkFramework("OpenGLES", .{});
                window_mod.addIncludePath(.{
                    .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "System/Library/SubFrameworks/UIUtilities.framework/Headers" }),
                });
                const ios_sources = &[_][]const u8{
                    "src/SFML/Window/iOS/ClipboardImpl.mm",
                    "src/SFML/Window/iOS/EaglContext.mm",
                    "src/SFML/Window/iOS/InputImpl.mm",
                    "src/SFML/Window/iOS/JoystickImpl.mm",
                    "src/SFML/Window/iOS/SensorImpl.mm",
                    "src/SFML/Window/iOS/VideoModeImpl.mm",
                    "src/SFML/Window/iOS/WindowImplUIKit.mm",
                    "src/SFML/Window/iOS/SFAppDelegate.mm",
                    // "src/SFML/Window/iOS/TestAppDelegate.mm",
                    "src/SFML/Window/iOS/SFView.mm",
                    "src/SFML/Window/iOS/SFViewController.mm",
                    "src/SFML/Window/iOS/SFMain.mm",
                    //"src/SFML/Main/MainiOS.mm",
                };

                for (ios_sources) |src| {
                    window_mod.addCSourceFile(.{
                        .file = upstream.path(src),
                        .language = .objective_cpp,
                        .flags = &.{"-fobjc-arc"},
                    });
                }
                window_mod.addCSourceFile(.{
                    .file = upstream.path("src/SFML/Window/iOS/CursorImpl.cpp"),
                    .language = .cpp,
                });
            },
            else => {},
        }
    }

    if (target.result.os.tag == .ios) {
        const main_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
            .link_libc = true,
        });

        main_mod.addCSourceFile(.{
            .file = upstream.path("src/SFML/Main/MainiOS.mm"),
            .language = .objective_cpp,
            .flags = &.{"-fobjc-arc"},
        });
        main_mod.addIncludePath(upstream.path("include"));
        main_mod.addIncludePath(upstream.path("src"));
        main_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/Frameworks" }) });
        main_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/System/Library/SubFrameworks" }) });
        main_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/usr/include" }) });
        main_mod.linkFramework("UIKit", .{});
        main_mod.linkFramework("UIUtilities", .{});
        main_mod.linkFramework("QuartzCore", .{});
        main_mod.linkFramework("CoreGraphics", .{});
        main_mod.linkFramework("CoreMotion", .{});
        main_mod.linkFramework("Foundation", .{});

        const libmain = b.addLibrary(.{
            .name = "sfml-main",
            .linkage = .static,
            .root_module = main_mod,
        });
        main_mod.linkLibrary(libwindow);
        b.installArtifact(libmain);
    }

    libsystem.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp", ".inl" } },
    );

    b.installArtifact(libnetwork);
    b.installArtifact(libgraphics);
    b.installArtifact(libsystem);
    b.installArtifact(libwindow);
    b.installArtifact(libaudio);
}
