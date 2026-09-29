const std = @import("std");

// ponytail: libopusurl (src/http.c, src/wincerts.c) is not built; it needs OpenSSL.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libc_include = b.option(std.Build.LazyPath, "libc_include", "Build without libc against these headers; the consumer provides the symbols");

    const ogg = b.dependency("ogg", .{ .target = target, .optimize = optimize, .libc_include = libc_include }).artifact("ogg");
    const opus = b.dependency("opus", .{ .target = target, .optimize = optimize, .libc_include = libc_include }).artifact("opus");

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = libc_include == null });
    if (libc_include) |p| mod.addIncludePath(p); // -I: must win over the macOS SDK headers zig always adds
    // Without libc the Windows file code (windows.h, io.h, _wfopen) cannot build; the consumer's
    // libc has no files anyway, so take the POSIX paths (they call its failing stubs).
    const no_win32: []const []const u8 = if (libc_include != null and target.result.os.tag == .windows)
        &.{ "-U_WIN32", "-UWIN32", "-U__WIN32__", "-U__MINGW32__" } // not _WIN64: used to detect LLP64
    else
        &.{};
    mod.addIncludePath(b.path("include"));
    mod.linkLibrary(ogg);
    mod.linkLibrary(opus);
    mod.addCMacro("OP_HAVE_LRINTF", "1");
    mod.addCSourceFiles(.{ .root = b.path("src"), .files = &.{ "info.c", "internal.c", "opusfile.c", "stream.c" }, .flags = no_win32 });

    const lib = b.addLibrary(.{ .name = "opusfile", .root_module = mod });
    lib.installHeader(b.path("include/opusfile.h"), "opusfile.h");
    lib.installLibraryHeaders(ogg);
    lib.installLibraryHeaders(opus);
    b.installArtifact(lib);
}
