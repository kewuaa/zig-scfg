const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Ast = @import("ast.zig").Ast;
const Parser = @import("parser.zig").Parser;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub fn parse(allocator: Allocator, source: [:0]const u8) !Ast {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(allocator, source);
    defer parser.deinit();

    while (true) {
        const token = tokenizer.next();
        try parser.feed(&token);
        if (token.tag == .eof) {
            break;
        }
    }

    const ast_nodes = try allocator.alloc(Ast.Node, parser.nodes.items.len);
    for (parser.nodes.items) |*node, i| {
        const children = try allocator.alloc(
            *Ast.Node,
            node.children.items.len,
        );
        for (node.children.items) |child, j| {
            children[j] = &ast_nodes[child];
        }
        ast_nodes[i] = .{
            .name = node.name,
            .params = node.params.toOwnedSlice(allocator),
            .children = children,
        };
    }

    const roots = try allocator.alloc(*Ast.Node, parser.roots.items.len);
    for (parser.roots.items) |root, i| {
        roots[i] = &ast_nodes[root];
    }

    return Ast{
        .source = source,
        .nodes = ast_nodes,
        .root = .{
            .name = "root",
            .params = &.{},
            .children = roots,
        },
    };
}

test {
    const source =
        \\model A2 {
        \\  speed 250
        \\  shape {
        \\    length 50
        \\    width 100
        \\  }
        \\}
        \\model C5 {
        \\  speed 350
        \\  shape {
        \\    length 10
        \\    width 260
        \\  }
        \\}
    ;

    var ast = try parse(testing.allocator, source);
    defer ast.deinit(testing.allocator);

    const models = try ast.getAll(testing.allocator, "model");
    defer testing.allocator.free(models);
    try testing.expectEqual(@as(usize, 2), models.len);

    const model_c5 = ast.find("model", &.{"C5"}).?;
    try testing.expectEqual(&ast.nodes[5], model_c5);

    const model_c5_speed = model_c5.get("speed").?.params[0];
    try testing.expectEqualStrings("350", model_c5_speed);
}
