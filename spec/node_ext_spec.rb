# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Psych::Nodes::Node do
  describe "#leading_comments" do
    it "has an array" do
      node = Psych::Nodes::Scalar.new("foo")
      expect(node.leading_comments).to eq([])
    end

    it "can be set with an array of comments" do
      node = Psych::Nodes::Scalar.new("foo")
      node.leading_comments = ["# Comment 1", "# Comment 2"]
      expect(node.leading_comments).to eq(["# Comment 1", "# Comment 2"])
    end

    it "wraps non-array values in an array" do
      node = Psych::Nodes::Scalar.new("foo")
      node.leading_comments = "# Single comment"
      expect(node.leading_comments).to eq(["# Single comment"])
    end
  end

  describe "#trailing_comments" do
    it "has an array" do
      node = Psych::Nodes::Scalar.new("foo")
      expect(node.trailing_comments).to eq([])
    end

    it "can be set with an array of comments" do
      node = Psych::Nodes::Scalar.new("foo")
      node.trailing_comments = ["# Comment 1", "# Comment 2"]
      expect(node.trailing_comments).to eq(["# Comment 1", "# Comment 2"])
    end

    it "wraps non-array values in an array" do
      node = Psych::Nodes::Scalar.new("foo")
      node.trailing_comments = "# Single comment"
      expect(node.trailing_comments).to eq(["# Single comment"])
    end
  end
end
