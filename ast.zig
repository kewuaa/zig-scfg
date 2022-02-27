const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Ast = struct {
    source: [:0]const u8,
    nodes: []const Node,
    root: Node,

    pub const Node = struct {
        name: []const u8,
        params: []const []const u8,
        children: []const *Node,

        pub fn get(self: *const Node, name: []const u8) ?*const Node {
            for (self.children) |child| {
                if (mem.eql(u8, name, child.name)) {
                    return child;
                }
            }
            return null;
        }

        pub fn getAll(
            self: *const Node,
            allocator: Allocator,
            name: []const u8,
        ) ![]*const Node {
            var nodes = std.ArrayList(*const Node).init(allocator);
            for (self.children) |child| {
                if (mem.eql(u8, name, child.name)) {
                    try nodes.append(child);
                }
            }
            return nodes.toOwnedSlice();
        }

        pub fn find(
            self: *const Node,
            name: []const u8,
            params: []const []const u8,
        ) ?*const Node {
            outer: for (self.children) |child| {
                if (!mem.eql(u8, name, child.name)) {
                    continue;
                }
                if (child.params.len != params.len) {
                    continue;
                }
                for (child.params) |param, i| {
                    if (!mem.eql(u8, params[i], param)) {
                        continue :outer;
                    }
                }
                return child;
            }
            return null;
        }
    };

    pub fn deinit(self: *Ast, allocator: Allocator) void {
        for (self.nodes) |node| {
            allocator.free(node.params);
            allocator.free(node.children);
        }
        allocator.free(self.root.children);
        allocator.free(self.nodes);
    }

    pub fn get(self: *const Ast, name: []const u8) ?*const Node {
        return self.root.get(name);
    }

    pub fn getAll(
        self: *const Ast,
        allocator: Allocator,
        name: []const u8,
    ) ![]*const Node {
        return self.root.getAll(allocator, name);
    }

    pub fn find(
        self: *const Ast,
        name: []const u8,
        params: []const []const u8,
    ) ?*const Node {
        return self.root.find(name, params);
    }
};
