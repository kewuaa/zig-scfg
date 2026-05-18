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
    comment,
};

utf8: unicode.Utf8Iterator,
index: usize,
codepoint: u21,

pub fn init(source: []const u8) !Tokenizer {
    const utf8_view = try unicode.Utf8View.init(source);

    return Tokenizer{
        .utf8 = utf8_view.iterator(),
        .index = 0,
        .codepoint = '\n',
    };
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
                '#' => {
                    state = .comment;
                },
                else => {
                    return .{
                        .tag = tag.?,
                        .loc = .{ .start = start, .end = self.index },
                    };
                },
            },
            .comment => switch (self.codepoint) {
                '\n' => {
                    state = .newline;
                },
                else => {},
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
    const source =
        \\
        \\model A2
        \\
    ;
    const expected_tokens = [_]Token{
        .{ .tag = .newline, .loc = .{ .start = 0, .end = 1 } },
        .{ .tag = .bare_string, .loc = .{ .start = 1, .end = 6 } },
        .{ .tag = .bare_string, .loc = .{ .start = 7, .end = 9 } },
        .{ .tag = .newline, .loc = .{ .start = 9, .end = 10 } },
        .{ .tag = .eof, .loc = .{ .start = 10, .end = 10 } },
    };

    var tokenizer = try Tokenizer.init(source);
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(std.testing.allocator);

    while (true) {
        const token = tokenizer.next();
        try tokens.append(std.testing.allocator, token);
        if (token.tag == .eof or token.tag == .invalid) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}

test "tokenizer: full" {
    const source =
        \\# comment
        \\model "E5" {
        \\  max-speed 320km/h
        \\
        \\  weight '453.5t' "\""
        \\  # indented comment
        \\  emoji 🙋‍♂️
        \\}
    ;
    const expected_tokens = [_]Token{
        .{ .tag = .newline, .loc = .{ .start = 0, .end = 10 } },
        .{ .tag = .bare_string, .loc = .{ .start = 10, .end = 15 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 16, .end = 20 } },
        .{ .tag = .l_brace, .loc = .{ .start = 21, .end = 22 } },
        .{ .tag = .newline, .loc = .{ .start = 22, .end = 25 } },
        .{ .tag = .bare_string, .loc = .{ .start = 25, .end = 34 } },
        .{ .tag = .bare_string, .loc = .{ .start = 35, .end = 42 } },
        .{ .tag = .newline, .loc = .{ .start = 42, .end = 46 } },
        .{ .tag = .bare_string, .loc = .{ .start = 46, .end = 52 } },
        .{ .tag = .squote_string, .loc = .{ .start = 53, .end = 61 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 62, .end = 66 } },
        .{ .tag = .newline, .loc = .{ .start = 66, .end = 90 } },
        .{ .tag = .bare_string, .loc = .{ .start = 90, .end = 95 } },
        .{ .tag = .bare_string, .loc = .{ .start = 96, .end = 109 } },
        .{ .tag = .newline, .loc = .{ .start = 109, .end = 110 } },
        .{ .tag = .r_brace, .loc = .{ .start = 110, .end = 111 } },
        .{ .tag = .eof, .loc = .{ .start = 111, .end = 111 } },
    };

    var tokenizer = try Tokenizer.init(source);
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(std.testing.allocator);

    while (true) {
        const token = tokenizer.next();
        try tokens.append(std.testing.allocator, token);
        if (token.tag == .eof or token.tag == .invalid) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}
