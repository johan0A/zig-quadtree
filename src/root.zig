const std = @import("std");
const QuadTree = @import("QuadTree.zig").QuadTree;
const testing = std.testing;

test "QuadTree tests" {
    // const quad_tree = QuadTree(comptime Leaf: type, comptime Context: type, comptime equalLeafFn: fn(leaf1:Leaf, leaf2:Leaf, context:Context)bool)
    const allocator = testing.allocator;
    var item = std.ArrayList(u32).init(allocator);
    var quad_tree = QuadTree(@TypeOf(item), null).init(allocator);
    defer quad_tree.deinit();
    var timer = try std.time.Timer.start();
    _ = try quad_tree.insert(&item, .{ 0, 0 });
    _ = try quad_tree.insert(&item, .{ 50, 50 });
    std.debug.print("Insertion time: {} \n", .{@as(f64, @floatFromInt(timer.read())) / 1_000_000_000});
    try quad_tree.print_as_grid();
}
