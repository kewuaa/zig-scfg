const std = @import("std");
const scfg = @import("scfg.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "example.scfg",
        1_000_000,
    );

    const root = try scfg.parse(allocator, source);
    std.log.info("identifier of the first directive: {s}", .{root[0].name});
}
