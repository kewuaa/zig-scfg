const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
const Parser = @This();

const Directive = struct {
    name: []const u8,
    params: ArrayListUnmanaged([]const u8),
    // indeces on the Parser.blocks list
    blocks: ArrayListUnmanaged(usize),
};

// indeces on the Parser.directives list
const Block = ArrayListUnmanaged(usize);

allocator: mem.Allocator,
source: []const u8,

state: enum { new, update } = .new,
directive_idx: usize = 0,

directives: ArrayListUnmanaged(Directive) = .empty,
blocks: ArrayListUnmanaged(Block) = .empty,
path: ArrayListUnmanaged(usize) = .empty,

pub fn feed(self: *Parser, token: Token) !void {
    switch (self.state) {
        .new => switch (token.tag) {
            .newline => {},
            .bare_string => {
                try self.directives.append(self.allocator, .{
                    .name = self.source[token.loc.start..token.loc.end],
                    .params = .empty,
                    .blocks = .empty,
                });
                self.directive_idx = self.directives.items.len - 1;

                // create top-level block on first directive
                if (self.blocks.items.len == 0) {
                    try self.blocks.append(self.allocator, .empty);
                    try self.path.append(self.allocator, 0);
                }

                // append newly created directive to current block
                const block_idx = self.path.items[self.path.items.len - 1];
                const block = &self.blocks.items[block_idx];
                try block.append(self.allocator, self.directive_idx);

                self.state = .update;
            },
            .r_brace => {
                if (self.path.items.len == 1) {
                    return error.InvalidToken;
                }
                _ = self.path.pop();
                self.state = .update;
            },
            .eof => {
                if (self.path.items.len > 1) {
                    return error.InvalidToken;
                }
            },
            else => {
                return error.InvalidToken;
            },
        },
        .update => switch (token.tag) {
            .bare_string => {
                const directive = &self.directives.items[self.directive_idx];
                const param = self.source[token.loc.start..token.loc.end];
                try directive.params.append(self.allocator, param);
            },
            // TODO: handle escape characters for dquote strigs
            .squote_string, .dquote_string => {
                const directive = &self.directives.items[self.directive_idx];
                const start = token.loc.start + 1;
                const end = token.loc.end - 1;
                const param = self.source[start..end];
                try directive.params.append(self.allocator, param);
            },
            .l_brace => {
                try self.blocks.append(self.allocator, .empty);
                const block_idx = self.blocks.items.len - 1;

                const directive = &self.directives.items[self.directive_idx];
                try directive.blocks.append(self.allocator, block_idx);
                try self.path.append(self.allocator, block_idx);
                self.state = .new;
            },
            .newline, .eof => {
                if (token.tag == .eof and self.path.items.len > 1) {
                    return error.InvalidToken;
                }
                self.state = .new;
            },
            else => {
                return error.InvalidToken;
            },
        },
    }
}

test "parser: minimal" {
    const source = "model A2 'A3'";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var tokenizer = try Tokenizer.init(source);
    var parser: Parser = .{ .allocator = arena.allocator(), .source = source };

    while (true) {
        const token = tokenizer.next();
        try parser.feed(token);
        if (token.tag == .eof) break;
    }

    try testing.expectEqual(@as(usize, 1), parser.directives.items.len);
    try testing.expectEqualStrings("model", parser.directives.items[0].name);

    try testing.expectEqual(@as(usize, 2), parser.directives.items[0].params.items.len);
    try testing.expectEqualStrings("A2", parser.directives.items[0].params.items[0]);
    try testing.expectEqualStrings("A3", parser.directives.items[0].params.items[1]);

    try testing.expectEqual(@as(usize, 1), parser.blocks.items.len);
    try testing.expectEqualSlices(usize, &.{0}, parser.blocks.items[0].items);
}

test "parser: directive with a block" {
    const source =
        \\# comment
        \\model A2 {
        \\  # comment
        \\  speed 250 kmph
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var tokenizer = try Tokenizer.init(source);
    var parser: Parser = .{ .allocator = arena.allocator(), .source = source };

    while (true) {
        const token = tokenizer.next();
        try parser.feed(token);
        if (token.tag == .eof) break;
    }

    try testing.expectEqual(@as(usize, 2), parser.blocks.items.len);
    try testing.expectEqual(@as(usize, 2), parser.directives.items.len);

    try testing.expectEqualStrings("model", parser.directives.items[0].name);
    try testing.expectEqual(@as(usize, 1), parser.directives.items[0].params.items.len);
    try testing.expectEqualStrings("A2", parser.directives.items[0].params.items[0]);

    try testing.expectEqual(@as(usize, 1), parser.directives.items[0].blocks.items.len);
    try testing.expectEqual(@as(usize, 1), parser.directives.items[0].blocks.items[0]);

    try testing.expectEqualStrings("speed", parser.directives.items[1].name);
    try testing.expectEqual(@as(usize, 2), parser.directives.items[1].params.items.len);
    try testing.expectEqualStrings("250", parser.directives.items[1].params.items[0]);
    try testing.expectEqualStrings("kmph", parser.directives.items[1].params.items[1]);
}
