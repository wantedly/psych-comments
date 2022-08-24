# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Psych::Nodes::Node do
  describe "#leading_comments" do
    it "has an array" do
      node = Psych::Nodes::Scalar.new("foo")
      expect(node.leading_comments).to eq([])
    end
  end

  describe "#trailing_comments" do
    it "has an array" do
      node = Psych::Nodes::Scalar.new("foo")
      expect(node.trailing_comments).to eq([])
    end
  end
end
