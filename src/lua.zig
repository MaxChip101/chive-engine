const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const io = std.io;
const ascii = std.ascii;

// NOTE: add parsing and ast stuff

pub const Script = struct {
    allocator: mem.Allocator,
    tokenizer: Tokenizer,
    parser: Parser,
    ast: ASTGenerator,
    interpereter: Interpereter,

    const Self = @This();

    pub fn init_from_path(allocator: mem.Allocator, source: []const u8) !Self {
        const tokenizer: Tokenizer = .init_from_path(allocator, source);
        const parser: Parser = .init(allocator);
        const ast: ASTGenerator = .init(allocator);
        const interpereter: Interpereter = .init(allocator);

        return .{
            .tokenizer = tokenizer,
            .parser = parser,
            .ast = ast,
            .interpereter = interpereter,
        };
    }

    pub fn init_from_content(allocator: mem.Allocator, content: []u8) !Self {
        const tokenizer: Tokenizer = .init_from_content(allocator, content);
        const parser: Parser = .init(allocator);
        const ast: ASTGenerator = .init(allocator);
        const interpereter: Interpereter = .init(allocator);

        return .{
            .tokenizer = tokenizer,
            .parser = parser,
            .ast = ast,
            .interpereter = interpereter,
        };
    }

    pub fn execute(self: *Self) !void {
        self.tokenizer.tokenize();
    }

    pub fn deinit(self: *Self) void {
        self.tokenizer.deinit();
        self.parser.deinit();
        self.ast.deinit();
        self.interpereter.deinit();
    }
};

pub const Interpereter = struct {
    allocator: mem.Allocator,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

pub const ASTGenerator = struct {
    allocator: mem.Allocator,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

pub const Parser = struct {
    allocator: mem.Allocator,
    tokenns: []const Token,
    current: usize = 0,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

pub const Tokenizer = struct {
    allocator: mem.Allocator,
    source: []const u8,
    content: []u8,
    tokens: std.ArrayList(Token),
    line: usize = 1,
    column: usize = 1,
    index: usize = 0,
    const Self = @This();

    pub fn init_from_path(allocator: mem.Allocator, source: []const u8) !Self {
        var file = try fs.openFileAbsolute(source, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try file.readToEndAlloc(allocator, file_size);
        return .{
            .allocator = allocator,
            .source = source,
            .content = content,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn init_from_content(allocator: mem.Allocator, content: []u8) !Self {
        return .{
            .allocator = allocator,
            .source = "",
            .content = content,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.content.len > 0) self.allocator.free(self.content);
        self.tokens.deinit();
    }

    pub fn tokenize(self: *Self) !void {
        while (self.peek(0)) |char| {
            switch (char) {
                ' ', '\t', '\r', '\n' => self.advance(),

                '-' => {
                    if (try self.handleComment()) {
                        continue;
                    } else {
                        try self.*.tokens.append(.{
                            .type = .Minus,
                            .value = self.content[self.index .. self.index + 1],
                            .line = self.line,
                        });
                        self.advance();
                    }
                },

                '"', '\'' => try self.handleString(),
                '0'...'9' => try self.handleNumber(),
                'a'...'z', 'A'...'Z', '_' => try self.handleIdentifier(),
                else => try self.handleSymbol(),
            }
        }

        try self.*.tokens.append(.{
            .type = .EOF,
            .value = "",
            .line = self.line,
        });
    }

    fn handleSymbol(self: *Self) !void {
        const start_index = self.index;
        const char = self.peek(0) orelse return;

        var token_type: TokenType = undefined;
        var length: usize = 1;

        switch (char) {
            '+' => token_type = .Plus,
            '-' => token_type = .Minus,
            '*' => token_type = .Multiply,
            '/' => token_type = .Divide,
            '(' => token_type = .LeftParen,
            ')' => token_type = .RightParen,
            '{' => token_type = .LeftBrace,
            '}' => token_type = .RightBrace,
            '[' => token_type = .LeftBracket,
            ']' => token_type = .RightBracket,
            ',' => token_type = .Comma,
            ';' => token_type = .Semicolon,
            ':' => token_type = .Colon,
            '=' => {
                if (self.peek(1) == '=') {
                    token_type = .Equals;
                    length = 2;
                } else {
                    token_type = .Assign;
                }
            },
            '~' => {
                if (self.peek(1) == '=') {
                    token_type = .NotEquals;
                    length = 2;
                } else {
                    token_type = .UnkownSymbol;
                    length = 1;
                }
            },
            '<' => {
                if (self.peek(1) == '=') {
                    token_type = .LessEqual;
                    length = 2;
                } else {
                    token_type = .LessThan;
                }
            },
            '>' => {
                if (self.peek(1) == '=') {
                    token_type = .GreaterEqual;
                    length = 2;
                } else {
                    token_type = .GreaterThan;
                }
            },
            else => {
                token_type = .UnkownSymbol;
                length = 1;
            },
        }
        try self.*.tokens.append(.{ .type = token_type, .value = self.content[start_index .. start_index + length], .line = self.line });
        self.advance_by(length);
    }

    fn handleIdentifier(self: *Self) !void {
        const start_index = self.index;
        while (self.peek(0)) |char| {
            if (ascii.isAlphanumeric(char) or char == '_') {
                self.advance();
            } else break;
        }

        const value = self.content[start_index..self.index];

        const token_type: TokenType = if (mem.eql(u8, value, "local")) .Local else if (mem.eql(u8, value, "function")) .Function //
            else if (mem.eql(u8, value, "if")) .If //
            else if (mem.eql(u8, value, "then")) .Then //
            else if (mem.eql(u8, value, "end")) .End //
            else if (mem.eql(u8, value, "nil")) .NilLiteral //
            else if (mem.eql(u8, value, "true") or mem.eql(u8, value, "false")) .BooleanLiteral //
            else if (mem.eql(u8, value, "and")) .And //
            else if (mem.eql(u8, value, "or")) .Or //
            else if (mem.eql(u8, value, "not")) .Not //
            else if (mem.eql(u8, value, "return")) .Return //
            else if (mem.eql(u8, value, "for")) .For //
            else if (mem.eql(u8, value, "do")) .Do //
            else if (mem.eql(u8, value, "while")) .While //
            else if (mem.eql(u8, value, "elseif")) .ElseIf //
            else if (mem.eql(u8, value, "else")) .Else //
            else .Identifier;

        try self.*.tokens.append(.{
            .type = token_type,
            .value = value,
            .line = self.line,
        });
    }

    fn handleNumber(self: *Self) !void {
        const start_index = self.index;
        var has_dot = false;

        while (self.peek(0)) |char| {
            if (ascii.isDigit(char)) {
                self.advance();
            } else if (char == '.' and !has_dot) {
                has_dot = true;
                self.advance();
            } else break;
        }

        try self.*.tokens.append(.{
            .type = .NumberLiteral,
            .value = self.content[start_index..self.index],
            .line = self.line,
        });
    }

    fn handleString(self: *Self) !void {
        const quote_type = self.peek(0).?;
        self.advance();
        const start_index = self.index;

        while (self.peek(0)) |char| {
            if (char == quote_type) break;
            self.advance();
        }

        const value = self.content[start_index..self.index];
        self.advance();

        try self.*.tokens.append(.{
            .type = .StringLiteral,
            .value = value,
            .line = self.line,
        });
    }

    fn handleComment(self: *Self) !bool {
        if (self.peek(0) == '-' and self.peek(1) == '-') {
            self.advance_by(2);

            if (self.peek(0) == '[' and self.peek(1) == '[') {
                self.advance_by(2);
                while (self.peek(0)) |char| {
                    if (char == ']' and self.peek(1) == ']') {
                        self.advance_by(2);
                        break;
                    }
                    self.advance();
                }
            } else {
                while (self.peek(0)) |char| {
                    if (char == '\n') break;
                    self.advance();
                }
            }
            return true;
        }
        return false;
    }

    fn peek(self: *Self, offset: usize) ?u8 {
        if (self.index + offset < self.content.len) {
            return self.content[self.index + offset];
        }
        return null;
    }

    fn advance(self: *Self) void {
        if (self.peek(0)) |char| {
            if (char == '\n') {
                self.*.line += 1;
                self.*.column = 1;
            } else {
                self.*.column += 1;
            }
            self.*.index += 1;
        }
    }

    fn advance_by(self: *Self, amount: usize) void {
        var _amount = amount;
        while (_amount > 0) {
            self.advance();
            _amount -= 1;
        }
    }
};

const Token = struct {
    type: TokenType,
    value: []const u8,
    line: usize,
};

const TokenType = enum {
    Local,
    Function,
    If,
    Else,
    ElseIf,
    Then,
    End,
    While,
    Do,
    For,
    Return,
    And,
    Or,
    Not,

    Plus,
    Minus,
    Multiply,
    Divide,
    Assign,
    Equals,
    NotEquals,
    LessThan,
    GreaterThan,
    LessEqual,
    GreaterEqual,
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Dot,
    Colon,
    Semicolon,
    UnkownSymbol,

    Identifier,
    StringLiteral,
    NumberLiteral,
    BooleanLiteral,
    NilLiteral,

    EOF,
};
