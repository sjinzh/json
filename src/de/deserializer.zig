const getty = @import("getty");
const std = @import("std");

pub fn Deserializer(comptime Reader: type) type {
    return struct {
        reader: Reader,
        scratch: std.ArrayList(u8),
        tokens: std.json.TokenStream,
        //remaining_depth: u8 = 128,
        //single_precision: bool = false,
        //disable_recursion_limit: bool = false,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator, reader: Reader) Self {
            var d = Self{
                .reader = reader,
                .scratch = std.ArrayList(u8).init(allocator),
                .tokens = undefined,
            };
            d.reader.readAllArrayList(&d.scratch, 10 * 1024 * 1024) catch unreachable;
            d.tokens = std.json.TokenStream.init(d.scratch.items);
            return d;
        }

        pub fn deinit(self: *Self) void {
            self.scratch.deinit();
        }

        /// Implements `getty.de.Deserializer`.
        pub usingnamespace getty.de.Deserializer(
            *Self,
            _D.Error,
            _D.deserializeBool,
            undefined,
            //_D.deserializeEnum,
            _D.deserializeFloat,
            _D.deserializeInt,
            undefined,
            //_D.deserializeMap,
            _D.deserializeOptional,
            undefined,
            //_D.deserializeSequence,
            undefined,
            //_D.deserializeString,
            undefined,
            //_D.deserializeStruct,
            _D.deserializeVoid,
        );

        const _D = struct {
            const Error = error{Input};

            fn deserializeBool(self: *Self, visitor: anytype) !@TypeOf(visitor).Value {
                if (self.tokens.next() catch return Error.Input) |token| {
                    switch (token) {
                        .True => return try visitor.visitBool(Error, true),
                        .False => return try visitor.visitBool(Error, false),
                        else => {},
                    }
                }

                return Error.Input;
            }

            fn deserializeFloat(self: *Self, visitor: anytype) !@TypeOf(visitor).Value {
                if (self.tokens.next() catch return Error.Input) |token| {
                    switch (token) {
                        .Number => |num| return try visitor.visitFloat(
                            Error,
                            std.fmt.parseFloat(@TypeOf(visitor).Value, num.slice(self.scratch.items, self.tokens.i - 1)) catch return Error.Input,
                        ),
                        else => {},
                    }
                }

                return Error.Input;
            }

            fn deserializeInt(self: *Self, visitor: anytype) !@TypeOf(visitor).Value {
                const Value = @TypeOf(visitor).Value;

                if (self.tokens.next() catch return Error.Input) |token| {
                    switch (token) {
                        .Number => |num| switch (num.is_integer) {
                            true => return try visitor.visitInt(
                                Error,
                                std.fmt.parseInt(Value, num.slice(self.scratch.items, self.tokens.i - 1), 10) catch return Error.Input,
                            ),
                            false => return visitor.visitFloat(
                                Error,
                                std.fmt.parseFloat(f128, num.slice(self.scratch.items, self.tokens.i - 1)) catch return Error.Input,
                            ),
                        },
                        else => {},
                    }
                }

                return Error.Input;
            }

            fn deserializeOptional(self: *Self, visitor: anytype) !@TypeOf(visitor).Value {
                const tokens = self.tokens;

                if (self.tokens.next() catch return Error.Input) |token| {
                    return try switch (token) {
                        .Null => visitor.visitNull(Error),
                        else => blk: {
                            // Get back the token we just ate if it was an
                            // actual value so that whenever the next
                            // deserialize method is called by visitSome,
                            // they'll eat the token we just saw instead of
                            // whatever is after it.
                            self.tokens = tokens;
                            break :blk visitor.visitSome(self.deserializer());
                        },
                    };
                }

                return Error.Input;
            }

            fn deserializeVoid(self: *Self, visitor: anytype) !@TypeOf(visitor).Value {
                if (self.tokens.next() catch return Error.Input) |token| {
                    if (token == .Null) {
                        return try visitor.visitVoid(Error);
                    }
                }

                return Error.Input;
            }
        };
    };
}
