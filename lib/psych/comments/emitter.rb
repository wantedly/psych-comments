module Psych
  module Comments
    module NodeUtils
      module_function def stringify_node(node)
        case node
        when Psych::Nodes::Stream
          node.to_yaml
        when Psych::Nodes::Document
          strm = Psych::Nodes::Stream.new
          strm.children << node
          stringify_node(strm)
        else
          doc = Psych::Nodes::Document.new([], [], true)
          doc.children << node
          stringify_node(doc)
        end
      end

      module_function def stringify_adjust_scalar(node, indent = 0)
        node2 = Psych::Nodes::Scalar.new(node.value, nil, nil, node.plain, node.quoted, node.style)
        if node.tag && !node.quoted
          node2.quoted = true
        end

        s = stringify_node(node2).sub(/\n\z/, "")
        if node.style == Psych::Nodes::Scalar::DOUBLE_QUOTED || node.style == Psych::Nodes::Scalar::SINGLE_QUOTED || node.style == Psych::Nodes::Scalar::PLAIN
          s = s.gsub(/\s*\n\s*/, " ")
        else
          s = s.gsub(/\n/, "\n#{INDENT * indent}")
        end
        s.gsub(/\n\s+$/, "\n")
      end

      module_function def single_line(node)
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Alias
          node.leading_comments.empty? && node.trailing_comments.empty?
        when Psych::Nodes::Mapping, Psych::Nodes::Sequence
          node.children.empty?
        else
          false
        end
      end

      module_function def has_bullet(node)
        node.is_a?(Psych::Nodes::Sequence) && !node.children.empty?
      end

      module_function def has_anchor(node)
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Mapping, Psych::Nodes::Sequence
          !!node.anchor
        else
          false
        end
      end
    end
    private_constant :NodeUtils

    class Emitter
      include NodeUtils

      INDENT = "  "

      attr_reader :out

      def initialize
        @out = ""
        @state = :init
        @indent = 0
        @flow = false
        @comment_lookahead = []
      end

      def print(text)
        case @state
        when :word_end
          @out << " "
        when :line_start
          @out << INDENT * @indent
        end
        @state = :in_line
        @out << text
      end

      def space!
        @state = :word_end
      end

      def newline!
        return if @state == :init || @state == :line_start || @state == :pseudo_indent
        @out << "\n"
        @state = :line_start
      end

      def emit(node)
        if node.equal?(@comment_lookahead[0])
          @comment_lookahead.shift
        else
          node.leading_comments.each do |comment|
            print comment
            newline!
          end
        end
        if has_anchor(node)
          print "&#{node.anchor}"
          space!
        end
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Alias
          if node.is_a?(Psych::Nodes::Alias)
            print "*#{node.anchor}"
          else
            print stringify_adjust_scalar(node, @indent)
          end
        when Psych::Nodes::Mapping
          set_flow(flow?(node)) do
            if @flow
              print "{"
              cont = false
              node.children.each_slice(2) do |(key, value)|
                if cont
                  print ","
                  space!
                end
                emit(key)
                print ":"
                space!
                emit(value)
                cont = true
              end
              print "}"
            else
              if node.children.empty?
                print "{}"
                return
              end
              newline!
              node.children.each_slice(2) do |(key, value)|
                emit(key)
                print ":"
                space!
                if single_line(value)
                  emit(value)
                elsif has_bullet(value)
                  emit(value)
                else
                  @indent += 1
                  emit(value)
                  @indent -= 1
                end
                newline!
              end
            end
          end
        when Psych::Nodes::Sequence
          set_flow(flow?(node)) do
            if @flow
              print "["
              cont = false
              node.children.each do |subnode|
                if cont
                  print ","
                  space!
                end
                emit(subnode)
                cont = true
              end
              print "]"
            else
              if node.children.empty?
                print "[]"
                return
              end
              newline!
              node.children.each do |subnode|
                emit_lookahead_comments(subnode) unless @flow
                print "- "
                @state = :pseudo_indent
                indented do
                  emit(subnode)
                end
                newline!
              end
            end
          end
        when Psych::Nodes::Document
          emit(node.root)
        when Psych::Nodes::Stream
          if node.children.size == 1 && node.children[0].implicit
            emit(node.children[0])
            return
          end
          node.children.each do |subnode|
            print "---"
            newline!
            emit(subnode)
          end
        else
          raise TypeError, node
        end
      end

      def emit_lookahead_comments(node)
        node.leading_comments.each do |comment|
          print comment
          newline!
        end
        @comment_lookahead.push(node)
        case node
        when Psych::Nodes::Mapping, Psych::Nodes::Sequence
          emit_lookahead_comments(node.children[0]) unless flow?(node)
        end
      end

      def indented(&block)
        @indent += 1
        begin
          block.()
        ensure
          @indent -= 1
        end
      end

      def set_flow(new_flow, &block)
        old_flow, @flow = @flow, new_flow
        begin
          block.()
        ensure
          @flow = old_flow
        end
      end

      def flow?(node)
        case node
        when Psych::Nodes::Mapping
          @flow || node.style == Psych::Nodes::Mapping::FLOW || node.children.empty?
        when Psych::Nodes::Sequence
          @flow || node.style == Psych::Nodes::Sequence::FLOW || node.children.empty?
        end
      end
    end

    private_constant :Emitter

    def self.emit_yaml(node)
      emitter = Emitter.new
      emitter.emit(node)
      emitter.out
    end
  end
end
