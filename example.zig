const std = @import("std");
const Io = std.Io;
const process = std.process;

const scfg = @import("scfg");

pub fn main(init: process.Init) !void {
    const allocator = init.arena.allocator();

    const source = try Io.Dir.cwd().readFileAlloc(
        init.io,
        "example.scfg",
        allocator,
        .limited(1_000_000),
    );

    const root = try scfg.parse(allocator, source);
    for (root) |directive| {
        std.log.info("name: {s}", .{ directive.name });
        std.log.info("params: {s}", .{ try std.mem.join(allocator, ", ", directive.params) });
    }
}
