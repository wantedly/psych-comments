# `Psych::Comments` -- brings YAML comment handling

This gem allows you to manipulate YAML, preserving comment information.

## Installation

```ruby
# Gemfile
gem 'psych-comments'
```

## Usage

```ruby
require "psych"
require "psych/comments"

ast = Psych::Comments.parse_stream(<<YAML)
# foo
- 42
# bar
- 12
YAML

ast.children[0].root.children.sort_by! do |node|
  node.value.to_i
end

puts Psych::Comments.emit_yaml(ast)
```

## API

### `Psych::Nodes::Node#leading_comments` -> `Array<String>`

Returns an array of leading comments. Each comment must start with `#`.

Extends [Psych::Nodes::Node](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Node.html).

### `Psych::Nodes::Mapping#inline_leading_comment` -> `String | nil`

Returns the inline comment immediately following the `{` character. Each comment must start with `#`.

Extends [Psych::Nodes::Mapping](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Mapping.html).

### `Psych::Nodes::Sequence#inline_leading_comment` -> `String | nil`

Returns the inline comment immediately following the `[` character. Each comment must start with `#`.

Extends [Psych::Nodes::Sequence](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Sequence.html).

### `Psych::Nodes::Node#inline_comment` -> `String | nil`

Returns the inline comment. Each comment must start with `#`.

Extends [Psych::Nodes::Node](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Node.html).

### `Psych::Nodes::Node#trailing_comments` -> `Array<String>`

Returns an array of leading comments. Each comment must start with `#`.

Extends [Psych::Nodes::Node](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Node.html).

### `Psych::Comments.parse(yaml, filename: nil)`

Parse YAML data with comments. Returns [Psych::Nodes::Document](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Document.html).

The interface is equivalent to [Psych.parse](https://docs.ruby-lang.org/en/3.1/Psych.html#method-c-parse).

### `Psych::Comments.parse_file(filename)`

Parse YAML data with comments. Returns [Psych::Nodes::Document](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Document.html).

The interface is equivalent to [Psych.parse_file](https://docs.ruby-lang.org/en/3.1/Psych.html#method-c-parse).

### `Psych::Comments.parse_stream(yaml, filename: nil, &block)`

Parse YAML stream with comments. Returns [Psych::Nodes::Stream](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Stream.html).

The interface is equivalent to [Psych.parse_stream](https://docs.ruby-lang.org/en/3.1/Psych.html#method-c-parse_stream).

### `Psych::Comments.emit_yaml(node)` -> `String`

Serializes the event tree into a string.

This method is similar to [`Psych::Nodes::Node#to_yaml`](https://docs.ruby-lang.org/en/3.1/Psych/Nodes/Node.html#method-i-to_yaml),
except that it takes comments into account.

Note that, this is essentially a reimplemention of libyaml's emitter.
The implementation is incomplete and you may observe an incorrect or inconsistent output
if you supply an AST containing unusual constructs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
