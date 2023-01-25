
# [zig-scfg]

[![builds.sr.ht status](https://builds.sr.ht/~andreafeletto/zig-scfg/commits/main.svg)](https://builds.sr.ht/~andreafeletto/zig-scfg/commits/main)

A [zig] library for parsing [scfg] configuration files.

## Setup

Clone this repository as a submodule.

```sh
git submodule add https://git.sr.ht/~andreafeletto/zig-scfg deps/zig-scfg
```

Than add the following to your `build.zig`.

```zig
pub fn build(b: *std.build.Builder) void {
    // ...
    const scfg: Pkg = .{
        .name = "scfg",
        .path = .{ .path = "deps/zig-scfg/scfg.zig" },
    };
    exe.addPackage(scfg);
    // ...
}
```

The library can now be imported into your zig project.

```zig
const scfg = @import("scfg");
```

## Usage

I suggested to use an arena allocator. The resulting tree structure can be quite
complex, so manual deallocation could be tricky.

```zig
const std = @import("std");
const scfg = @import("scfg");

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
```

The result of the `parse` function is a slice of pointers to directives.
Each directive has the following recursive structure:

```zig
const Directive = struct {
    name: []const u8,
    params: [][]const u8,
    blocks: [][]*Directive,
};
```

## Contributing

The code in this repository is released under the MIT license.
You are welcome to send patches to the [mailing list] or report bugs on the
[issue tracker].

If you aren't familiar with `git send-email`, you can use the [web interface]
or learn about it following this excellent [tutorial].

[zig-scfg]: https://sr.ht/~andreafeletto/zig-scfg/
[zig]: https://ziglang.org/
[scfg]: https://git.sr.ht/~emersion/scfg/
[mailing list]: https://lists.sr.ht/~andreafeletto/public-inbox
[issue tracker]: https://todo.sr.ht/~andreafeletto/zig-scfg
[web interface]: https://git.sr.ht/~andreafeletto/zig-scfg/send-email
[tutorial]: https://git-send-email.io
