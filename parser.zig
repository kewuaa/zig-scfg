const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Token = @import("tokenizer.zig").Token;

pub const Parser = struct {
    allocator: Allocator,
    source: [:0]const u8,

    state: enum { new, update },
    index: usize,

    nodes: std.ArrayListUnmanaged(struct {
        name: []const u8,
        params: std.ArrayListUnmanaged([]const u8),
        children: std.ArrayListUnmanaged(usize),
    }),
    roots: std.ArrayListUnmanaged(usize),
    path: std.ArrayListUnmanaged(usize),

    pub fn init(allocator: Allocator, source: [:0]const u8) Parser {
        return Parser{
            .allocator = allocator,
            .source = source,
            .state = .new,
            .index = 0,
            .nodes = .{},
            .roots = .{},
            .path = .{},
        };
    }

    pub fn deinit(self: *Parser) void {
        for (self.nodes.items) |*node| {
            node.params.deinit(self.allocator);
            node.children.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);
        self.roots.deinit(self.allocator);
        self.path.deinit(self.allocator);
    }

    pub fn feed(self: *Parser, token: *const Token) !void {
        switch (self.state) {
            .new => switch (token.tag) {
                .newline => {},
                .bare_string => {
                    try self.nodes.append(self.allocator, .{
                        .name = self.source[token.loc.start..token.loc.end],
                        .params = .{},
                        .children = .{},
                    });
                    if (self.path.items.len != 0) {
                        const parent = self.path.items[self.path.items.len - 1];
                        const siblings = &self.nodes.items[parent].children;
                        try siblings.append(self.allocator, self.index);
                    } else {
                        try self.roots.append(self.allocator, self.index);
                    }
                    self.state = .update;
                    self.index += 1;
                },
                .r_brace => {
                    _ = self.path.pop();
                },
                .eof => {
                    if (self.path.items.len != 0) {
                        return error.InvalidToken;
                    }
                },
                else => {
                    return error.InvalidToken;
                },
            },
            .update => switch (token.tag) {
                .bare_string => {
                    const param = self.source[token.loc.start..token.loc.end];

                    const node = &self.nodes.items[self.index - 1];
                    try node.params.append(self.allocator, param);
                },
                // TODO: handle escape characters for dquote strigs
                .squote_string, .dquote_string => {
                    const start = token.loc.start + 1;
                    const end = token.loc.end - 1;
                    const param = self.source[start..end];

                    const node = &self.nodes.items[self.index - 1];
                    try node.params.append(self.allocator, param);
                },
                .l_brace => {
                    self.state = .new;
                    try self.path.append(self.allocator, self.index - 1);
                },
                .newline, .eof => {
                    self.state = .new;
                },
                else => {
                    return error.InvalidToken;
                },
            },
        }
    }
};
