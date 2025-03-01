# frozen_string_literal: true

class Psych::Nodes::Node
  def leading_comments
    @leading_comments ||= []
  end

  def trailing_comments
    @trailing_comments ||= []
  end

  def leading_comments=(comments)
    @leading_comments = Array(comments)
  end

  def trailing_comments=(comments)
    @trailing_comments = Array(comments)
  end
end
