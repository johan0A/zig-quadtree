const std = @import("std");
const QuadTree = @import("QuadTree.zig").QuadTree;
const testing = std.testing;

test "QuadTree tests" {
    // const quad_tree = QuadTree(comptime Leaf: type, comptime Context: type, comptime equalLeafFn: fn(leaf1:Leaf, leaf2:Leaf, context:Context)bool)
    const allocator = testing.allocator;
    var item = std.ArrayList(u32).init(allocator);
    var quad_tree = QuadTree(@TypeOf(item)).init(allocator);
    _ = try quad_tree.insert(&item, .{ 0, 0 });
    _ = try quad_tree.insert(&item, .{ 2, 2 });
    _ = try quad_tree.insert(&item, .{ 32000, 32000 });
    try quad_tree.display();
}
