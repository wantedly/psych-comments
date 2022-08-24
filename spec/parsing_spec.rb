# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe "Parsing" do
  describe "#parse" do
    it "returns Psych::Nodes::Document" do
      ast = Psych::Comments.parse("- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "accepts filename" do
      ast = Psych::Comments.parse("- 1", filename: "foo.yml")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "accepts IO" do
      ast = Psych::Comments.parse(StringIO.new "- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "attaches comments to a scalar" do
      ast = Psych::Comments.parse("# foo\nbar" + <<~YAML)
        # foo
        bar
      YAML
      expect(ast.root.leading_comments).to eq(["# foo"])
    end

    it "attaches multiple comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        # bar
        baz
      YAML
      expect(ast.root.leading_comments).to eq(["# foo", "# bar"])
    end

    it "attaches comments to a mapping key" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        bar: baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
    end

    it "attaches comments to a mapping value" do
      ast = Psych::Comments.parse(<<~YAML)
        bar:
          # foo
          baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[1].leading_comments).to eq(["# foo"])
    end

    it "attaches comments to sequence elements" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        - foo1
        - # bar
          bar2
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
      expect(ast.root.children[1].leading_comments).to eq(["# bar"])
    end

    it "attaches comments to flow mapping" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        {
          foo: bar
          # bar
        }
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.leading_comments).to eq(["# foo"])
      expect(ast.root.children[1].trailing_comments).to eq(["# bar"])
    end

    it "attaches comments to flow sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        [
          foo
          # bar
        ]
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect(ast.root.leading_comments).to eq(["# foo"])
      expect(ast.root.children[0].trailing_comments).to eq(["# bar"])
    end

    it "attaches comments to document" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        ---
        # bar
        1
      YAML
      expect(ast.leading_comments).to eq(["# foo"])
      expect(ast.root.leading_comments).to eq(["# bar"])
    end

    it "attaches trailing comments in the last node of document" do
      ast = Psych::Comments.parse(<<~YAML)
        1
        # foo
        ...
        # bar
      YAML
      expect(ast.root.trailing_comments).to eq(["# foo"])
      expect(ast.trailing_comments).to eq(["# bar"])
    end
  end
end
