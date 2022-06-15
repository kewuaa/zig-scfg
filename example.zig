const std = @import("std");
const scfg = @import("scfg.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("example.scfg", .{});
    // `source` must be a null-terminated string
    const source = try file.readToEndAllocOptions(allocator, 1_000_000, null, @alignOf(u8), 0);

    const root = try scfg.parse(allocator, source);
    std.log.info("identifier of the first directive: {s}", .{root[0].name});
}
