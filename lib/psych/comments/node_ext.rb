# frozen_string_literal: true

class Psych::Nodes::Node
  def leading_comments
    @leading_comments ||= []
  end

  def line_end_comments
    @line_end_comments ||= []
  end

  def trailing_comments
    @trailing_comments ||= []
  end

  alias end_column_without_comment end_column
  def end_column
    end_column_without_comment + (line_end_comments[0]&.length || 0)
  end
end
