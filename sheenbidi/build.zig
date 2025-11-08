const std = @import("std");

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
    const t = target.result;
    _ = t;
    const optimize = b.standardOptimizeOption(.{});

    const sheenbidi = b.dependency("sheenbidi", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });

    module.addIncludePath(sheenbidi.path("Headers"));

    module.addCSourceFiles(.{
        .root = sheenbidi.path("Source"),
        .files = try sources(
            b.allocator,
            sheenbidi.path("Source").getPath(b),
        ),
    });

    const lib = b.addLibrary(.{
        .name = "sheenbidi",
        .linkage = .static,
        .root_module = module,
    });
    lib.installHeadersDirectory(sheenbidi.path("Headers"), "", .{});
    b.installArtifact(lib);
}
