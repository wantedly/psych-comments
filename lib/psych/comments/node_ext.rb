# frozen_string_literal: true

class Psych::Nodes::Node
  def leading_comments
    @leading_comments ||= []
  end

  attr_accessor :line_end_comment

  def trailing_comments
    @trailing_comments ||= []
  end

  alias end_column_without_comment end_column
  def end_column
    end_column_without_comment + (line_end_comment&.length || 0)
  end
end
