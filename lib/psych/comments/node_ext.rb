# frozen_string_literal: true

class Psych::Nodes::Node
  def leading_comments
    @leading_comments ||= []
  end

  def trailing_comments
    @trailing_comments ||= []
  end
end
