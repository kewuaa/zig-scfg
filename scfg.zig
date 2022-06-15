const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("src/Parser.zig");
const Tokenizer = @import("src/Tokenizer.zig");

const Block = []*Directive;

const Directive = struct {
    name: []const u8,
    params: [][]const u8,
    blocks: []Block,
};

pub fn parse(allocator: Allocator, source: [:0]const u8) !Block {
    var tokenizer = Tokenizer.init(source);
    var parser: Parser = .{ .allocator = allocator, .source = source };

    while (true) {
        const token = tokenizer.next();
        try parser.feed(&token);
        if (token.tag == .eof) {
            break;
        }
    }

    const directives = try allocator.alloc(Directive, parser.directives.items.len);
    const blocks = try allocator.alloc(Block, parser.blocks.items.len);

    // convert blocks from arrays of indeces to arrays of pointers
    for (parser.blocks.items) |*block, i| {
        blocks[i] = try allocator.alloc(*Directive, block.items.len);
        for (block.items) |directive_idx, j| {
            blocks[i][j] = &directives[directive_idx];
        }
    }

    // copy directives and replace parser blocks with pointer-based blocks
    for (parser.directives.items) |*directive, i| {
        directives[i] = .{
            .name = directive.name,
            .params = directive.params.toOwnedSlice(allocator),
            .blocks = try allocator.alloc(Block, directive.blocks.items.len),
        };
        for (directive.blocks.items) |block_idx, j| {
            directives[i].blocks[j] = blocks[block_idx];
        }
    }

    _ = allocator.resize(blocks, 1);
    return blocks[0];
}

test "parse: minimal" {
    const source = "model A2 thin";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const root = try parse(arena.allocator(), source);
    try testing.expectEqual(@as(usize, 1), root.len);
    try testing.expectEqualStrings("model", root[0].name);
    try testing.expectEqual(@as(usize, 2), root[0].params.len);
    try testing.expectEqualStrings("A2", root[0].params[0]);
    try testing.expectEqualStrings("thin", root[0].params[1]);
}

test "parse: directives with a block" {
    const source =
        \\model A2 {
        \\  speed 250
        \\}
        \\model A3 {
        \\  speed 270
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const root = try parse(arena.allocator(), source);
    try testing.expectEqual(@as(usize, 2), root.len);

    try testing.expectEqualStrings("model", root[0].name);
    try testing.expectEqual(@as(usize, 1), root[0].params.len);
    try testing.expectEqualStrings("A2", root[0].params[0]);
    try testing.expectEqualStrings("speed", root[0].blocks[0][0].name);
    try testing.expectEqualStrings("250", root[0].blocks[0][0].params[0]);

    try testing.expectEqualStrings("model", root[1].name);
    try testing.expectEqual(@as(usize, 1), root[1].params.len);
    try testing.expectEqualStrings("A3", root[1].params[0]);
    try testing.expectEqualStrings("speed", root[1].blocks[0][0].name);
    try testing.expectEqualStrings("270", root[1].blocks[0][0].params[0]);
}
