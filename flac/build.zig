const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const t = target.result;
    const optimize = b.standardOptimizeOption(.{});

    const flac = b.dependency("flac", .{
        .target = target,
        .optimize = optimize,
    });

    const config_header = b.addConfigHeader(
        .{
            .style = .{
                .cmake = flac.path("config.cmake.h.in"),
            },
            .include_path = "config.h",
        },
        .{
            .CPU_IS_BIG_ENDIAN = t.cpu.arch.endian() == .big,
            .ENABLE_64_BIT_WORDS = t.ptrBitWidth() == 64,
            .FLAC__ALIGN_MALLOC_DATA = t.cpu.arch.isX86(),
            .FLAC__CPU_ARM64 = t.cpu.arch.isAARCH64(),
            .FLAC__SYS_DARWIN = t.os.tag == .macos,
            .FLAC__SYS_LINUX = t.os.tag == .linux,
            .FLAC_NO_DLL = t.os.tag == .windows,
            .HAVE_BYTESWAP_H = t.os.tag == .linux,
            .HAVE_CPUID_H = t.cpu.arch.isX86(),
            .HAVE_FSEEKO = true,
            .HAVE_ICONV = t.os.tag != .windows,
            .HAVE_INTTYPES_H = true,
            .HAVE_MEMORY_H = true,
            .HAVE_STDINT_H = true,
            .HAVE_STRING_H = true,
            .HAVE_STDLIB_H = true,
            .HAVE_TYPEOF = true,
            .HAVE_UNISTD_H = true,
            .GIT_COMMIT_DATE = "GIT_COMMIT_DATE",
            .GIT_COMMIT_HASH = "GIT_COMMIT_HASH",
            .GIT_COMMIT_TAG = "GIT_COMMIT_TAG",
            .PROJECT_VERSION = "hexops/flac",
        },
    );

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });

    module.addConfigHeader(config_header);
    module.addCMacro("HAVE_CONFIG_H", "1");
    module.addCMacro("FLAC_NO_DLL", "1");
    module.addIncludePath(config_header.getOutput().dirname());
    module.addIncludePath(flac.path("include"));
    module.addIncludePath(flac.path("src/libFLAC/include"));
    module.addCSourceFiles(.{
        .root = flac.path(""),
        .files = sources,
    });
    if (t.os.tag == .windows) {
        module.addCMacro("FLAC__NO_DLL", "1");
        module.addCSourceFiles(.{
            .root = flac.path(""),
            .files = sources_windows,
        });
    }

    // Install config header to flac dependency path
    const install_config = b.addInstallFile(config_header.getOutput(), "config.h");
    b.getInstallStep().dependOn(&install_config.step);

    const lib = b.addLibrary(.{
        .name = "flac",
        .linkage = .static,
        .root_module = module,
    });
    lib.installConfigHeader(config_header);
    lib.installHeadersDirectory(flac.path("include"), "", .{});
    b.installArtifact(lib);
}

const sources = &[_][]const u8{
    "src/libFLAC/bitmath.c",
    "src/libFLAC/bitreader.c",
    "src/libFLAC/bitwriter.c",
    "src/libFLAC/cpu.c",
    "src/libFLAC/crc.c",
    "src/libFLAC/fixed.c",
    "src/libFLAC/fixed_intrin_sse2.c",
    "src/libFLAC/fixed_intrin_ssse3.c",
    "src/libFLAC/fixed_intrin_sse42.c",
    "src/libFLAC/fixed_intrin_avx2.c",
    "src/libFLAC/float.c",
    "src/libFLAC/format.c",
    "src/libFLAC/lpc.c",
    "src/libFLAC/lpc_intrin_neon.c",
    "src/libFLAC/lpc_intrin_sse2.c",
    "src/libFLAC/lpc_intrin_sse41.c",
    "src/libFLAC/lpc_intrin_avx2.c",
    "src/libFLAC/lpc_intrin_fma.c",
    "src/libFLAC/md5.c",
    "src/libFLAC/memory.c",
    "src/libFLAC/metadata_iterators.c",
    "src/libFLAC/metadata_object.c",
    "src/libFLAC/stream_decoder.c",
    "src/libFLAC/stream_encoder.c",
    "src/libFLAC/stream_encoder_intrin_sse2.c",
    "src/libFLAC/stream_encoder_intrin_ssse3.c",
    "src/libFLAC/stream_encoder_intrin_avx2.c",
    "src/libFLAC/stream_encoder_framing.c",
    "src/libFLAC/window.c",
};

const sources_windows = &[_][]const u8{
    "src/share/win_utf8_io/win_utf8_io.c",
};
