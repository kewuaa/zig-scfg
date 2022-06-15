const std = @import("std");
const testing = std.testing;

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

source: [:0]const u8,
index: usize,

pub fn init(source: [:0]const u8) Tokenizer {
    return Tokenizer{ .source = source, .index = 0 };
}

pub fn next(self: *Tokenizer) Token {
    var state: State = .start;
    var token: Token = .{
        .tag = .eof,
        .loc = .{ .start = self.index, .end = undefined },
    };

    while (true) : (self.index += 1) {
        const char = self.source[self.index];

        switch (state) {
            .start => switch (char) {
                0 => {
                    break;
                },
                ' ', '\t', '\r' => {
                    token.loc.start = self.index + 1;
                },
                '\n' => {
                    state = .newline;
                    token.tag = .newline;
                },
                '\'' => {
                    state = .squote_string;
                    token.tag = .squote_string;
                },
                '"' => {
                    state = .dquote_string;
                    token.tag = .dquote_string;
                },
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                    state = .bare_string;
                    token.tag = .bare_string;
                },
                '{' => {
                    self.index += 1;
                    token.tag = .l_brace;
                    token.loc.end = self.index;
                    return token;
                },
                '}' => {
                    self.index += 1;
                    token.tag = .r_brace;
                    token.loc.end = self.index;
                    return token;
                },
                else => {
                    token.tag = .invalid;
                    token.loc.end = self.index;
                    self.index += 1;
                    return token;
                },
            },
            .bare_string => switch (char) {
                0, ' ', '\t', '\r', '\n', '{', '}' => {
                    break;
                },
                '"', '\'' => {
                    token.tag = .invalid;
                    token.loc.end = self.index;
                    self.index += 1;
                    return token;
                },
                else => {},
            },
            .squote_string => switch (char) {
                '\'' => {
                    self.index += 1;
                    break;
                },
                0, '\n' => {
                    token.tag = .invalid;
                    token.loc.end = self.index;
                    return token;
                },
                else => {},
            },
            .dquote_string => switch (char) {
                '"' => {
                    self.index += 1;
                    break;
                },
                0, '\n' => {
                    token.tag = .invalid;
                    token.loc.end = self.index;
                    return token;
                },
                '\\' => {
                    self.index += 1;
                },
                else => {},
            },
            .newline => switch (char) {
                '\n' => {},
                else => {
                    break;
                },
            },
        }
    }

    token.loc.end = self.index;
    return token;
}

test "tokenizer: minimal" {
    const source = "model A2";
    const expected_tokens = [_]Token{
        .{ .tag = .bare_string, .loc = .{ .start = 0, .end = 5 } },
        .{ .tag = .bare_string, .loc = .{ .start = 6, .end = 8 } },
        .{ .tag = .eof, .loc = .{ .start = 8, .end = 8 } },
    };

    var tokenizer = Tokenizer.init(source);
    var tokens = std.ArrayList(Token).init(testing.allocator);
    defer tokens.deinit();

    while (true) {
        const token = tokenizer.next();
        try tokens.append(token);
        if (token.tag == .eof) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}

test "tokenizer: full" {
    const source =
        \\model "E5" {
        \\   max-speed 320km/h
        \\
        \\   weight '453.5t' "\""
        \\}
    ;
    const expected_tokens = [_]Token{
        .{ .tag = .bare_string, .loc = .{ .start = 0, .end = 5 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 6, .end = 10 } },
        .{ .tag = .l_brace, .loc = .{ .start = 11, .end = 12 } },
        .{ .tag = .newline, .loc = .{ .start = 12, .end = 13 } },
        .{ .tag = .bare_string, .loc = .{ .start = 16, .end = 25 } },
        .{ .tag = .bare_string, .loc = .{ .start = 26, .end = 33 } },
        .{ .tag = .newline, .loc = .{ .start = 33, .end = 35 } },
        .{ .tag = .bare_string, .loc = .{ .start = 38, .end = 44 } },
        .{ .tag = .squote_string, .loc = .{ .start = 45, .end = 53 } },
        .{ .tag = .dquote_string, .loc = .{ .start = 54, .end = 58 } },
        .{ .tag = .newline, .loc = .{ .start = 58, .end = 59 } },
        .{ .tag = .r_brace, .loc = .{ .start = 59, .end = 60 } },
        .{ .tag = .eof, .loc = .{ .start = 60, .end = 60 } },
    };

    var tokenizer = Tokenizer.init(source);
    var tokens = std.ArrayList(Token).init(testing.allocator);
    defer tokens.deinit();

    while (true) {
        const token = tokenizer.next();
        try tokens.append(token);
        if (token.tag == .eof) break;
    }

    try testing.expectEqualSlices(Token, &expected_tokens, tokens.items);
}
