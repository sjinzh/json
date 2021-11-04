const escape = @import("details/escape.zig");
const fmt = @import("details/fmt.zig");
const std = @import("std");

const Formatter = @import("../../../lib.zig").ser.Formatter;

pub fn PrettyFormatter(comptime Writer: type) type {
    return struct {
        current: usize,
        has_value: bool,
        indent: []const u8,

        const Self = @This();
        const impl = @"impl PrettyFormatter"(Writer);

        /// Construct a pretty printer formatter that defaults to using two
        /// spaces for indentation.
        pub fn init() Self {
            return initWithIndent("  ");
        }

        /// Construct a pretty printer formatter that uses the `indent` string
        /// for indentation.
        pub fn initWithIndent(indent: []const u8) Self {
            return .{
                .current = 0,
                .has_value = false,
                .indent = indent,
            };
        }

        fn doIndent(self: *Self, writer: anytype) Writer.Error!void {
            var i: usize = 0;

            while (i < self.current) : (i += 1) {
                try writer.writeAll(self.indent);
            }
        }

        pub usingnamespace Formatter(
            *Self,
            Writer,
            impl.formatter.writeNull,
            impl.formatter.writeBool,
            impl.formatter.writeInt,
            impl.formatter.writeFloat,
            impl.formatter.writeNumberString,
            impl.formatter.beginString,
            impl.formatter.endString,
            impl.formatter.writeStringFragment,
            impl.formatter.writeCharEscape,
            impl.formatter.beginArray,
            impl.formatter.endArray,
            impl.formatter.beginArrayValue,
            impl.formatter.endArrayValue,
            impl.formatter.beginObject,
            impl.formatter.endObject,
            impl.formatter.beginObjectKey,
            impl.formatter.endObjectKey,
            impl.formatter.beginObjectValue,
            impl.formatter.endObjectValue,
            impl.formatter.writeRawFragment,
        );
    };
}

fn @"impl PrettyFormatter"(comptime Writer: type) type {
    const Self = PrettyFormatter(Writer);

    return struct {
        pub const formatter = struct {
            pub fn writeNull(_: *Self, writer: Writer) Writer.Error!void {
                try writer.writeAll("null");
            }

            pub fn writeBool(_: *Self, writer: Writer, value: bool) Writer.Error!void {
                try writer.writeAll(if (value) "true" else "false");
            }

            pub fn writeInt(_: *Self, writer: Writer, value: anytype) Writer.Error!void {
                try fmt.formatInt(value, writer);
            }

            pub fn writeFloat(_: *Self, writer: Writer, value: anytype) Writer.Error!void {
                var buf: [512]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);

                std.fmt.formatFloatDecimal(value, std.fmt.FormatOptions{}, stream.writer()) catch |err| switch (err) {
                    error.NoSpaceLeft => unreachable,
                    else => unreachable, // TODO: handle error
                };

                // TODO: fix getPos error
                try writer.writeAll(buf[0 .. stream.getPos() catch unreachable]);
            }

            pub fn writeNumberString(_: *Self, writer: Writer, value: []const u8) Writer.Error!void {
                try writer.writeAll(value);
            }

            pub fn beginString(_: *Self, writer: Writer) Writer.Error!void {
                try writer.writeAll("\"");
            }

            pub fn endString(_: *Self, writer: Writer) Writer.Error!void {
                try writer.writeAll("\"");
            }

            pub fn writeStringFragment(_: *Self, writer: Writer, value: []const u8) Writer.Error!void {
                try writer.writeAll(value);
            }

            pub fn writeCharEscape(_: *Self, writer: Writer, value: u21) Writer.Error!void {
                try escape.escapeChar(value, writer);
            }

            pub fn beginArray(self: *Self, writer: Writer) Writer.Error!void {
                self.current += 1;
                self.has_value = false;
                try writer.writeAll("[");
            }

            pub fn endArray(self: *Self, writer: Writer) Writer.Error!void {
                self.current -= 1;

                if (self.has_value) {
                    try writer.writeAll("\n");
                    try self.doIndent(writer);
                }

                try writer.writeAll("]");
            }

            pub fn beginArrayValue(self: *Self, writer: Writer, first: bool) Writer.Error!void {
                if (first) {
                    try writer.writeAll("\n");
                } else {
                    try writer.writeAll(",\n");
                }

                try self.doIndent(writer);
            }

            pub fn endArrayValue(self: *Self, writer: Writer) Writer.Error!void {
                _ = writer;

                self.has_value = true;
            }

            pub fn beginObject(self: *Self, writer: Writer) Writer.Error!void {
                self.current += 1;
                self.has_value = false;
                try writer.writeAll("{");
            }

            pub fn endObject(self: *Self, writer: Writer) Writer.Error!void {
                self.current -= 1;

                if (self.has_value) {
                    try writer.writeAll("\n");
                    try self.doIndent(writer);
                }

                try writer.writeAll("}");
            }

            pub fn beginObjectKey(self: *Self, writer: Writer, first: bool) Writer.Error!void {
                if (first) {
                    try writer.writeAll("\n");
                } else {
                    try writer.writeAll(",\n");
                }

                try self.doIndent(writer);
            }

            pub fn endObjectKey(self: *Self, writer: Writer) Writer.Error!void {
                _ = self;
                _ = writer;
            }

            pub fn beginObjectValue(self: *Self, writer: Writer) Writer.Error!void {
                _ = self;

                try writer.writeAll(": ");
            }

            pub fn endObjectValue(self: *Self, writer: Writer) Writer.Error!void {
                _ = writer;

                self.has_value = true;
            }

            pub fn writeRawFragment(self: *Self, writer: Writer, value: []const u8) Writer.Error!void {
                _ = self;

                try writer.writeAll(value);
            }
        };
    };
}
