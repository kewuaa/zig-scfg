const std = @import("std");
const testing = std.testing;
const unicode = std.unicode;

const Tokenizer = @This();

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        bare_string,
        squote_string,
        dquote_string,
        l_brace,
        r_brace,
        newline,
        eof,
        invalid,
    };
};

const State = enum {
    start,
    bare_string,
    squote_string,
    dquote_string,
    newline,
};

utf8: unicode.Utf8Iterator,
index: usize,
codepoint: u21,

pub fn init(source: []const u8) !Tokenizer {
    const utf8_view = try unicode.Utf8View.init(source);
    var utf8_iter = utf8_view.iterator();
    const first = utf8_iter.nextCodepoint() orelse 0;

    return Tokenizer{ .utf8 = utf8_iter, .index = 0, .codepoint = first };
}

pub fn next(self: *Tokenizer) Token {
    var state: State = .start;
    var tag: ?Token.Tag = null;
    var start = self.index;

    while (true) {
        switch (state) {
            .start => switch (self.codepoint) {
                0 => {
                    tag = .eof;
                    break;
                },
                ' ', '\t', '\r' => {
                    start = self.utf8.i;
                },
                '\n' => {
                    state = .newline;
                    tag = .newline;
                },
                '\'' => {
                    state = .squote_string;
                    tag = .squote_string;
                },
                '"' => {
                    state = .dquote_string;
                    tag = .dquote_string;
                },
                '{' => {
                    tag = .l_brace;
                    break;
                },
                '}' => {
                    tag = .r_brace;
                    break;
                },
                else => {
                    state = .bare_string;
                    tag = .bare_string;
                },
            },
            .bare_string => switch (self.codepoint) {
                0, ' ', '\t', '\r', '\n', '{', '}' => {
                    return .{
                        .tag = tag.?,
                        .loc = .{ .start = start, .end = self.index },
                    };
                },
                '"', '\'' => {
                    tag = .invalid;
                    break;
                },
                else => {},
            },
            .squote_string => switch (self.codepoint) {
                '\'' => {
                    break;
                },
                0, '\n' => {
                    tag = .invalid;
                    break;
                },
                else => {},
            },
            .dquote_string => switch (self.codepoint) {
                '"' => {
                    break;
                },
                0, '\n' => {
                    tag = .invalid;
                    break;
                },
                '\\' => {
                    self.index = self.utf8.i;
                    self.codepoint = self.utf8.nextCodepoint() orelse 0;
                },
                else => {},
            },
            .newline => switch (self.codepoint) {
                '\n', ' ', '\t', '\r' => {},
                else => {
                    return .{
                        .tag = tag.?,
                        .loc = .{ .start = start, .end = self.index },
                    };
                },
            },
        }

        self.index = self.utf8.i;
        self.codepoint = self.utf8.nextCodepoint() orelse 0;
    }

    self.index = self.utf8.i;
    self.codepoint = self.utf8.nextCodepoint() orelse 0;

    return .{
        .tag = tag.?,
        .loc = .{ .start = start, .end = self.index },
    };
}

test "tokenizer: minimal" {
    const source = "model A2";
    const expected_tokens = [_]Token{
        .{ .tag = .bare_string, .loc = .{ .start = 0, .end = 5 } },
        .{ .tag = .bare_string, .loc = .{ .start = 6, .end = 8 } },
        .{ .tag = .eof, .loc = .{ .start = 8, .end = 8 } },
    };

    var tokenizer = try Tokenizer.init(source);
    var tokens = std.ArrayList(Token).init(testing.allocator);
    defer tokens.deinit();

    while (true) {
        const token = tokenizer.next();
        try tokens.append(token);
        if (token.tag == .eof or token.tag == .invalid) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}

test "tokenizer: full" {
    const source =
        \\model "E5" {
        \\  max-speed 320km/h
        \\
        \\  weight '453.5t' "\""
        \\  emoji 🙋‍♂️
        \\}
    ;
    const expected_tokens = [_]Token{
        .{ .tag = .bare_string, .loc = .{ .start = 0, .end = 5 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 6, .end = 10 } },
        .{ .tag = .l_brace, .loc = .{ .start = 11, .end = 12 } },
        .{ .tag = .newline, .loc = .{ .start = 12, .end = 15 } },
        .{ .tag = .bare_string, .loc = .{ .start = 15, .end = 24 } },
        .{ .tag = .bare_string, .loc = .{ .start = 25, .end = 32 } },
        .{ .tag = .newline, .loc = .{ .start = 32, .end = 36 } },
        .{ .tag = .bare_string, .loc = .{ .start = 36, .end = 42 } },
        .{ .tag = .squote_string, .loc = .{ .start = 43, .end = 51 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 52, .end = 56 } },
        .{ .tag = .newline, .loc = .{ .start = 56, .end = 59 } },
        .{ .tag = .bare_string, .loc = .{ .start = 59, .end = 64 } },
        .{ .tag = .bare_string, .loc = .{ .start = 65, .end = 78 } },
        .{ .tag = .newline, .loc = .{ .start = 78, .end = 79 } },
        .{ .tag = .r_brace, .loc = .{ .start = 79, .end = 80 } },
        .{ .tag = .eof, .loc = .{ .start = 80, .end = 80 } },
    };

    var tokenizer = try Tokenizer.init(source);
    var tokens = std.ArrayList(Token).init(testing.allocator);
    defer tokens.deinit();

    while (true) {
        const token = tokenizer.next();
        try tokens.append(token);
        if (token.tag == .eof or token.tag == .invalid) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}
