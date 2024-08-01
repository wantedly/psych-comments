# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe "Parsing" do
  describe "#parse" do
    def walk(node, &block)
      block.call(node)
      node.children&.each { |child| walk(child, &block) }
    end

    def expect_comments(ast, expected)
      expected ||= {}
      expected[:inline_leading_comment] ||= {}
      expected[:inline_comment] ||= {}
      expected[:leading_comments] ||= {}
      expected[:trailing_comments] ||= {}

      expected[:leading_comments].default = []
      expected[:trailing_comments].default = []

      walk(ast) do |node|
        if node.respond_to?(:inline_leading_comment)
          expect(node.inline_leading_comment).to(
            eq(expected[:inline_leading_comment][node]),
            "expected #{node} to have inline leading comment #{expected[:inline_leading_comment][node].inspect}, got #{node.inline_leading_comment.inspect}"
          )
        end
        expect(node.inline_comment).to(
          eq(expected[:inline_comment][node]),
          "expected #{node} to have inline comment #{expected[:inline_comment][node].inspect}, got #{node.inline_comment.inspect}"
        )
        expect(node.leading_comments).to(
          eq(expected[:leading_comments][node]),
          "expected #{node} to have leading comments #{expected[:leading_comments][node].inspect}, got #{node.leading_comments.inspect}"
        )
        expect(node.trailing_comments).to(
          eq(expected[:trailing_comments][node]),
          "expected #{node} to have trailing_comments comments #{expected[:trailing_comments][node].inspect}, got #{node.trailing_comments.inspect}"
        )
      end
    end

    it "returns Psych::Nodes::Document" do
      ast = Psych::Comments.parse("- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
      expect_comments(ast, nil)
    end

    it "accepts filename" do
      ast = Psych::Comments.parse("- 1", filename: "foo.yml")
      expect(ast).to be_a(Psych::Nodes::Document)
      expect_comments(ast, nil)
    end

    it "accepts IO" do
      ast = Psych::Comments.parse(StringIO.new "- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "attaches comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        bar
      YAML
      expect_comments(ast, leading_comments: { ast.root => ["# foo"] })
    end

    it "attaches inline comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        bar # foo
      YAML
      expect_comments(ast, inline_comment: { ast.root => "# foo" })
    end

    it "attaches multiple comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        # bar
        baz
      YAML
      expect_comments(ast, leading_comments: { ast.root => ["# foo", "# bar"] })
    end

    it "attaches leading comments to a mapping key" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        bar: baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(ast, leading_comments: { ast.root.children[0] => ["# foo"] })
    end

    it "attaches inline comments to a mapping key" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: # foo
          foo
        bar: # bar
          - bar
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(ast, inline_comment: {
        ast.root.children[0] => "# foo",
        ast.root.children[2] => "# bar"
      })
    end

    it "attaches inline comments to a mapping value" do
      ast = Psych::Comments.parse(<<~YAML)
        bar: baz # foo
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(ast, inline_comment: {
        ast.root.children[1] => "# foo"
      })
    end

    it "attaches leading comments to a mapping value" do
      ast = Psych::Comments.parse(<<~YAML)
        bar:
          # foo
          baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(ast, leading_comments: {
        ast.root.children[1] => ["# foo"]
      })
    end

    it "attaches comments to sequence elements" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        - foo1
        - # bar
          bar2
        # baz-a
        - # baz-b
          foo3: bar3 # baz-c
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect_comments(ast, leading_comments: {
        ast.root.children[0] => ["# foo"],
        ast.root.children[1] => ["# bar"],
        ast.root.children[2] => ["# baz-a"],
        ast.root.children[2].children[0] => ["# baz-b"]
      }, inline_comment: {
        ast.root.children[2].children[1] => "# baz-c"
      })
    end

    it "attaches inline comments to sequence elements containing flow mappings/sequences" do
      ast = Psych::Comments.parse(<<~YAML)
        - [] # empty array
        - [1, 2] # array of integers
        - {} # empty map
        - { foo: bar } # map with one key-value pair
      YAML
      expect_comments(ast, inline_comment: {
        ast.root.children[0] => "# empty array",
        ast.root.children[1] => "# array of integers",
        ast.root.children[2] => "# empty map",
        ast.root.children[3] => "# map with one key-value pair"
      })
    end

    it "attaches inline comments to empty flow mapping/sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: {} # foo
        bar: [] # bar
      YAML

      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(ast, inline_comment: {
        ast.root.children[1] => "# foo",
        ast.root.children[3] => "# bar"
      })
    end

    it "attaches inline comments only to flow mapping/sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: { key: "name", values: 1 } # foo
        bar: [{ key: "name", values: 2}] # bar
        baz:
        - { key: "name", values: 3 } # baz
      YAML
      expect_comments(ast, inline_comment: {
        ast.root.children[1] => "# foo",
        ast.root.children[3] => "# bar",
        ast.root.children[5].children[0] => "# baz"
      })
    end

    it "attaches comments to flow mapping" do
      ast = Psych::Comments.parse(<<~YAML)
        # leading
        { # inline leading
          # foo
          foo: bar # bar
          # baz
        } # inline trailing
        # trailing
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect_comments(
        ast,
        leading_comments: {
          ast.root => ["# leading"],
          ast.root.children[0] => ["# foo"]
        },
        inline_leading_comment: {
          ast.root => "# inline leading"
        },
        inline_comment: {
          ast.root => "# inline trailing",
          ast.root.children[1] => "# bar",
        },
        trailing_comments: {
          ast => ["# trailing"],
          ast.root.children[1] => ["# baz"]
        }
      )
    end

    it "attaches comments to flow sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        # leading
        [ # inline leading
          # foo
          foo # bar
          # baz
        ] # inline trailing
        # trailing
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect_comments(
        ast,
        leading_comments: {
          ast.root => ["# leading"],
          ast.root.children[0] => ["# foo"]
        },
        inline_leading_comment: {
          ast.root => "# inline leading"
        },
        inline_comment: {
          ast.root => "# inline trailing",
          ast.root.children[0] => "# bar"
        },
        trailing_comments: {
          ast => ["# trailing"],
          ast.root.children[0] => ["# baz"]
        }
      )
    end

    it "attaches comments to document" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        ---
        # bar
        1
      YAML
      expect_comments(ast, leading_comments: {
        ast => ["# foo"],
        ast.root => ["# bar"]
      })
    end

    it "attaches trailing comments in the last node of document" do
      ast = Psych::Comments.parse(<<~YAML)
        1
        # foo
        ...
        # bar
      YAML
      expect_comments(ast, trailing_comments: {
        ast.root => ["# foo"],
        ast => ["# bar"]
      })
    end

    it "doesn't get confused by block scalars" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: |
          # foo
          - bar
        # foobar
        foobar: "foobar"
      YAML
      expect_comments(ast, leading_comments: {
        ast.root.children[2] => ["# foobar"]
      })
    end
  end
end
