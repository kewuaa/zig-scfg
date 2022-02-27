
# [zig-scfg]

A [zig] library for [scfg].

## Usage

First clone this repository as a submodule.

```sh
git submodule add https://git.sr.ht/~andreafeletto/zig-scfg deps/zig-scfg
```

Than add the following to `build.zig`.

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

## Documentation

The function `parse` takes an allocator and a null-terminated string and
generates a tree.
The tree is owned by the caller, who is responsible for calling `deinit`.
The tree contains references to the source string, so the latter should not be
deallocated before the tree.

```zig
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

var tree = try scfg.parse(allocator, source);
defer tree.deinit(allocator);
```

The function `getAll` returns a slice (owned by the caller) of the top-level
directives filtered by their name.

```zig
const models = try ast.getAll(allocator, "model");
defer allocator.free(models);
```

The function `find` returns the first top-level directive with matching name
and parameters.
The parameters are compared in order and the lengths must be equal.
If no match is found, `null` is returned.

```zig
const model_c5 = ast.find("model", &.{"C5"}) orelse {
    std.log.err("not found", .{});
    return;
};
```

Every function can also be called on a directive.
The function `get` returns the first top-level directive with matching name.
If no match is found, `null` is returned.

```zig
const model_c5_speed = model_c5.get("speed") orelse {
    std.log.err("not found", .{});
    return;
};
```

The parameters of a directive can be accessed through the `params` field.

```zig
const speed_value = model_c5_speed.params[0];
```

## License

The code in this repository is released under the MIT license.

[zig-scfg]: https://sr.ht/~andreafeletto/zig-scfg/
[zig]: https://ziglang.org/
[scfg]: https://git.sr.ht/~emersion/scfg/
