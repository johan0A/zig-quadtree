const std = @import("std");

pub fn QuadTree(
    comptime Leaf: type,
    comptime deinitFn: ?fn (*Leaf) void,
) type {
    return struct {
        pub const Node = union(enum) {
            branch: *Branch,
            leaf: *Leaf,
            empty: void,
        };

        pub const Branch = struct {
            children: [2][2]Node = .{.{.empty} ** 2} ** 2,
        };

        const Self = @This();

        allocator: std.mem.Allocator,
        root: Node,
        min_pos: ?@Vector(2, i32),
        tree_height: u32,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = .empty,
                .min_pos = null,
                .tree_height = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            const DeinitFn = struct {
                fn deinit_node(node: Node, allocator: std.mem.Allocator) void {
                    switch (node) {
                        .empty => {},
                        .leaf => {},
                        .branch => {
                            for (node.branch.children) |row| {
                                for (row) |child| {
                                    deinit_node(child, allocator);
                                }
                            }
                            allocator.destroy(node.branch);
                        },
                    }
                }
            };
            DeinitFn.deinit_node(self.root, self.allocator);
        }

        pub fn deinitWithLeaves(self: *Self) void {
            const DeinitFn = struct {
                fn deinit_node(node: Node, allocator: std.mem.Allocator) void {
                    switch (node) {
                        .empty => {},
                        .leaf => if (deinitFn != null) deinitFn(node.leaf.*),
                        .branch => {
                            for (node.branch.children) |row| {
                                for (row) |child| {
                                    try deinit_node(child, allocator);
                                }
                            }
                            allocator.destroy(node.branch);
                        },
                    }
                }
            };
            DeinitFn.deinit_node(self.root, self.allocator);
        }

        fn local_pos_get(self: Self, local_pos: @Vector(2, i32)) ?*Leaf {
            var local_pos_ = local_pos;
            var current_node_height = self.tree_height;
            var current_node = &self.root;

            while (current_node_height > 0) : (current_node_height -= 1) {
                switch (current_node.*) {
                    .empty => {
                        return null;
                    },
                    .branch => {},
                    .leaf => unreachable,
                }
                const half_size = @as(usize, 1) << @intCast(current_node_height - 1);
                const child_index_x: usize = @intFromBool(local_pos_[1] >= half_size);
                const child_index_y: usize = @intFromBool(local_pos_[0] >= half_size);
                if (child_index_x == 1) local_pos_[1] -= @intCast(half_size);
                if (child_index_y == 1) local_pos_[0] -= @intCast(half_size);
                current_node = &current_node.branch.children[child_index_x][child_index_y];
            }
            if (current_node.* == .empty) {
                return null;
            }
            return current_node.*.leaf;
        }

        pub fn get(self: Self, pos: @Vector(2, i32)) ?*Leaf {
            const local_pos = pos - self.min_pos.?;
            return local_pos_get(self, local_pos);
        }

        // places a leaf at the given position in the quadtree, will return the existing leaf at that position if it exists
        pub fn swap(
            self: *Self,
            leaf: *Leaf,
            pos: @Vector(2, i32),
        ) !?*Leaf {
            if (self.root == .empty) {
                self.min_pos = pos;
                self.root = .{ .leaf = leaf };
                return null;
            }

            var local_pos = pos - self.min_pos.?;
            var max_pos = @as(u32, 1) << @intCast(self.tree_height);
            while (local_pos[0] < 0 or local_pos[1] < 0 or local_pos[0] >= max_pos or local_pos[1] >= max_pos) {
                try self.increase_height();
                local_pos = pos - self.min_pos.?;
                max_pos = std.math.pow(@TypeOf(max_pos), 2, self.tree_height);
            }

            var current_node_height = self.tree_height;
            var current_node = &self.root;

            while (current_node_height > 0) : (current_node_height -= 1) {
                switch (current_node.*) {
                    .empty => {
                        current_node.* = Node{ .branch = try self.allocator.create(Branch) };
                        current_node.*.branch.* = Branch{};
                    },
                    .branch => {},
                    .leaf => unreachable,
                }
                const half_size = @as(usize, 1) << @intCast(current_node_height - 1);
                const child_index_x: usize = @intFromBool(local_pos[1] >= half_size);
                const child_index_y: usize = @intFromBool(local_pos[0] >= half_size);
                if (child_index_x == 1) local_pos[1] -= @intCast(half_size);
                if (child_index_y == 1) local_pos[0] -= @intCast(half_size);
                current_node = &current_node.branch.children[child_index_x][child_index_y];
            }

            switch (current_node.*) {
                .empty => {
                    current_node.* = .{ .leaf = leaf };
                    return null;
                },
                .leaf => |leaf_| {
                    current_node.* = .{ .leaf = leaf };
                    return leaf_;
                },
                .branch => unreachable,
            }
            return null;
        }

        // inserts a leaf at the given position in the quadtree, will deinitalize the existing leaf at that position if it exists
        pub fn insert(
            self: *Self,
            leaf: *Leaf,
            pos: @Vector(2, i32),
        ) !void {
            if (try swap(self, leaf, pos)) |existing_leaf| {
                if (deinitFn != null) deinitFn(existing_leaf);
            }
        }

        // returns all leaves in the quadtree using a breath-first search
        pub fn get_all_leaves(self: Self) !std.ArrayList(Leaf) {
            var queue = std.ArrayList(Node).init(self.allocator);
            try queue.append(self.root);

            var leaves = std.ArrayList(Leaf).init(self.allocator);
            defer leaves.deinit();

            while (queue.items.len > 0) {
                const node = queue.pop();
                switch (node) {
                    .empty => {},
                    .leaf => try leaves.append(node.leaf.*),
                    .branch => {
                        for (node.branch.children) |row| {
                            for (row) |child| {
                                try queue.append(child);
                            }
                        }
                    },
                }
            }
        }

        // display of the quadtree in the terminal as a tree for debugging purposes
        // also serves as an example of how to traverse the quadtree
        pub fn print_as_tree(self: Self) !void {
            const DisplayFn = struct {
                fn display_node(node: Node, depth: u32) !void {
                    for (0..depth) |_| {
                        std.debug.print("   ", .{});
                    }

                    switch (node) {
                        .empty => std.debug.print("{} => E\n", .{depth}),
                        .leaf => std.debug.print("{} => L\n", .{depth}),
                        .branch => {
                            std.debug.print("{} => B\n", .{depth});
                            for (node.branch.children) |row| {
                                for (row) |child| {
                                    try display_node(child, depth + 1);
                                }
                            }
                        },
                    }
                }
            };
            try DisplayFn.display_node(self.root, 0);
        }

        // increases the height of the quadtree by one by adding a new root node and making the current root a child of this new root
        fn increase_height(self: *Self) !void {
            self.tree_height += 1;
            var new_root = Node{ .branch = try self.allocator.create(Branch) };
            new_root.branch.* = Branch{};
            new_root.branch.children[0][0] = self.root;
            self.root = new_root;
        }
    };
}
