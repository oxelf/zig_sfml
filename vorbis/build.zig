const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const t = target.result;
    _ = t;
    const optimize = b.standardOptimizeOption(.{});

    const ogg_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });
    ogg_mod.addIncludePath(b.path("ogg/include/"));

    ogg_mod.addCSourceFiles(.{
        .root = b.path("ogg/"),
        .files = ogg_sources,
        .flags = &[_][]const u8{},
    });

    const libogg = b.addLibrary(.{
        .name = "ogg",
        .linkage = .static,
        .root_module = ogg_mod,
    });

    const vorbis = b.dependency("vorbis", .{
        .target = target,
        .optimize = optimize,
    });

    // #ifndef __CONFIG_TYPES_H__
    // #define __CONFIG_TYPES_H__
    //
    // /* these are filled in by configure or cmake*/
    // #define INCLUDE_INTTYPES_H @INCLUDE_INTTYPES_H@
    // #define INCLUDE_STDINT_H @INCLUDE_STDINT_H@
    // #define INCLUDE_SYS_TYPES_H @INCLUDE_SYS_TYPES_H@
    //
    // #if INCLUDE_INTTYPES_H
    // #  include <inttypes.h>
    // #endif
    // #if INCLUDE_STDINT_H
    // #  include <stdint.h>
    // #endif
    // #if INCLUDE_SYS_TYPES_H
    // #  include <sys/types.h>
    // #endif
    //
    // typedef @SIZE16@ ogg_int16_t;
    // typedef @USIZE16@ ogg_uint16_t;
    // typedef @SIZE32@ ogg_int32_t;
    // typedef @USIZE32@ ogg_uint32_t;
    // typedef @SIZE64@ ogg_int64_t;
    // typedef @USIZE64@ ogg_uint64_t;
    //
    // #endif
    // const config_header = b.addConfigHeader(.{ .include_path = "ogg/include/config_types.h", .style = .{ .cmake = b.path("ogg/config_types.h.in") } }, .{
    //     .INCLUDE_INT_TYPES_H = true,
    //     .INCLUDE_STDINT_H = true,
    //     .INCLUDE_SYS_TYPES_H = true,
    //     .SIZE16 = "int16_t",
    //     .USIZE16 = "uint16_t",
    //     .SIZE32 = "int32_t",
    // });

    // const config_header = b.addConfigHeader(
    //     .{
    //         .style = .{
    //             .cmake = vorbis.path("configure.ac"),
    //         },
    //         .include_path = "config.h",
    //     },
    //     .{
    //         .CPU_IS_BIG_ENDIAN = t.cpu.arch.endian() == .big,
    //         .ENABLE_64_BIT_WORDS = t.ptrBitWidth() == 64,
    //         .FLAC__ALIGN_MALLOC_DATA = t.cpu.arch.isX86(),
    //         .FLAC__CPU_ARM64 = t.cpu.arch.isAARCH64(),
    //         .FLAC__SYS_DARWIN = t.os.tag == .macos,
    //         .FLAC__SYS_LINUX = t.os.tag == .linux,
    //         .HAVE_BYTESWAP_H = t.os.tag == .linux,
    //         .HAVE_CPUID_H = t.cpu.arch.isX86(),
    //         .HAVE_FSEEKO = true,
    //         .HAVE_ICONV = t.os.tag != .windows,
    //         .HAVE_INTTYPES_H = true,
    //         .HAVE_MEMORY_H = true,
    //         .HAVE_STDINT_H = true,
    //         .HAVE_STRING_H = true,
    //         .HAVE_STDLIB_H = true,
    //         .HAVE_TYPEOF = true,
    //         .HAVE_UNISTD_H = true,
    //         .GIT_COMMIT_DATE = "GIT_COMMIT_DATE",
    //         .GIT_COMMIT_HASH = "GIT_COMMIT_HASH",
    //         .GIT_COMMIT_TAG = "GIT_COMMIT_TAG",
    //         .PROJECT_VERSION = "hexops/flac",
    //     },
    // );

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });

    // module.addConfigHeader(config_header);
    // module.addCMacro("HAVE_CONFIG_H", "1");
    //module.addIncludePath(config_header.getOutput().dirname());
    module.addIncludePath(vorbis.path("include"));
    module.addIncludePath(vorbis.path("lib"));
    module.addIncludePath(b.path("ogg/include/"));
    module.addCSourceFiles(.{
        .root = vorbis.path(""),
        .files = sources,
    });
    // if (t.os.tag == .windows) {
    //     module.addCMacro("FLAC__NO_DLL", "1");
    //     module.addCSourceFiles(.{
    //         .root = flac.path(""),
    //         .files = sources_windows,
    //     });
    // }

    // Install config header to flac dependency path
    //const install_config = b.addInstallFile(config_header.getOutput(), "config.h");
    //b.getInstallStep().dependOn(&install_config.step);

    const lib = b.addLibrary(.{
        .name = "vorbis",
        .linkage = .static,
        .root_module = module,
    });
    lib.linkLibrary(libogg);
    //lib.installConfigHeader(config_header);
    lib.installHeadersDirectory(vorbis.path("include"), "", .{});
    lib.installHeadersDirectory(b.path("ogg/include"), "", .{});
    b.installArtifact(lib);
}

const sources = &[_][]const u8{
    "lib/analysis.c",
    "lib/bitrate.c",
    "lib/block.c",
    "lib/codebook.c",
    "lib/envelope.c",
    "lib/floor0.c",
    "lib/floor1.c",
    "lib/info.c",
    "lib/lpc.c",
    "lib/lsp.c",
    "lib/mapping0.c",
    "lib/mdct.c",
    "lib/psy.c",
    "lib/registry.c",
    "lib/res0.c",
    "lib/sharedbook.c",
    "lib/smallft.c",
    "lib/synthesis.c",
    "lib/vorbisenc.c",
    "lib/vorbisfile.c",
    "lib/window.c",
};

const ogg_sources = &[_][]const u8{
    "src/bitwise.c",
    "src/framing.c",
};

// const sources_windows = &[_][]const u8{
//     "src/share/win_utf8_io/win_utf8_io.c",
// };
