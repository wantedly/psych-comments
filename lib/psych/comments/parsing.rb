module Psych
  module Comments
    class Analyzer
      def initialize(text)
        @lines = text.lines.to_a
        @last = [0, 0]
        @bullet_owner = nil
      end

      def sublines(sl, sc, el, ec)
        if el < sl
          ""
        elsif el == sl
          (@lines[sl] || "")[sc...ec]
        else
          (@lines[sl] || "")[sc...] +
            @lines[sl + 1...el].join("") +
            (@lines[el] || "")[...ec]
        end
      end

      def char_at(l, c)
        (@lines[l] || "")[c]
      end

      def read_comments(line, column)
        s = sublines(*@last, line, column)
        @last = [line, column]
        comments = []
        s.scan(/-|#.*?$/) do |token|
          case token
          when "-"
            if @bullet_owner
              @bullet_owner.leading_comments.push(*comments)
              comments = []
            end
          else
            comments << token
          end
        end
        @bullet_owner = nil
        comments
      end

      def visit(node)
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Alias
          node.leading_comments.push(*read_comments(node.start_line, node.start_column))
          rest_of_line = sublines(node.end_line, node.end_column, node.end_line, -1)
          node.line_end_comments << rest_of_line.lstrip if rest_of_line =~ /^\s+#/
          @last = [node.end_line, node.end_column]
        when Psych::Nodes::Sequence, Psych::Nodes::Mapping
          has_delim = /[\[{]/.match?(char_at(node.start_line, node.start_column))
          has_bullet = node.is_a?(Psych::Nodes::Sequence) && !has_delim
          # Special-case on `- #foo\n  bar: baz`
          node.leading_comments.push(*read_comments(node.start_line, node.start_column)) if has_delim
          node.children.each do |subnode|
            @bullet_owner = subnode if has_bullet
            visit(subnode)
          end
          if has_delim
            rest_of_line = sublines(node.end_line, node.end_column, node.end_line, -1)
            if rest_of_line && rest_of_line =~ /^\s+#/
              node.line_end_comments << rest_of_line.lstrip
              @last = [node.end_line, node.end_column]
            end

            target = node.children[-1] || node
            target.trailing_comments.push(*read_comments(node.end_line, node.end_column))
          end
        when Psych::Nodes::Document
          if !node.implicit
            node.leading_comments.push(*read_comments(node.start_line, node.start_column))
          end
          visit(node.root)
          if !node.implicit_end
            node.root.trailing_comments.push(*read_comments(node.end_line, node.end_column))
          end
        when Psych::Nodes::Stream
          node.children.each do |subnode|
            visit(subnode)
          end
          target = node.children[-1] || node
          target.trailing_comments.push(*read_comments(node.end_line, node.end_column))
        else
          raise TypeError
        end
      end
    end

    private_constant :Analyzer

    def self.parse(yaml, filename: nil)
      parse_stream(yaml, filename: filename) do |node|
        return node
      end
      false
    end

    def self.parse_file(filename)
      File.open filename, 'r:bom|utf-8' do |f|
        parse f, filename: filename
      end
    end

    def self.parse_stream(yaml, filename: nil, &block)
      filename ||= yaml.respond_to?(:path) ? yaml.path : "<unknown>"
      yaml = yaml.read if yaml.respond_to?(:read)
      ast = Psych.parse_stream(yaml, filename: filename)
      Analyzer.new(yaml).visit(ast)
      if block_given?
        ast.children.each do |doc|
          block.(doc)
        end
        nil
      else
        ast
      end
    end
  end
end
