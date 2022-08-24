module Psych
  module Comments
    class Emitter
      INDENT = "  "

      attr_reader :out

      def initialize
        @out = ""
        @state = :init
        @indent = 0
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

      def self.stringify_node(node, indent = 0)
        node2 = Psych::Nodes::Scalar.new(node.value, nil, nil, node.plain, node.quoted, node.style)
        if node.tag && !node.quoted
          node2.quoted = true
        end
        doc = Psych::Nodes::Document.new([], [], true)
        doc.children << node2
        strm = Psych::Nodes::Stream.new
        strm.children << doc

        s = strm.to_yaml.sub(/\n\z/, "")
        if node.style == Psych::Nodes::Scalar::DOUBLE_QUOTED || node.style == Psych::Nodes::Scalar::SINGLE_QUOTED || node.style == Psych::Nodes::Scalar::PLAIN
          s = s.gsub(/\s*\n\s*/, " ")
        else
          s = s.gsub(/\n/, "\n#{INDENT * indent}")
        end
        s.gsub(/\n\s+$/, "\n")
      end

      def self.single_line(node)
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Alias
          node.leading_comments.empty? && node.trailing_comments.empty?
        when Psych::Nodes::Mapping, Psych::Nodes::Sequence
          node.children.empty?
        else
          false
        end
      end

      def self.has_bullet(node)
        node.is_a?(Psych::Nodes::Sequence) && !node.children.empty?
      end

      def self.has_anchor(node)
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Mapping, Psych::Nodes::Sequence
          !!node.anchor
        else
          false
        end
      end

      def emit(node)
        if node.leading_comments
          node.leading_comments.each do |comment|
            print comment
            newline!
          end
        end
        if Emitter.has_anchor(node)
          print "&#{node.anchor}"
          space!
        end
        case node
        when Psych::Nodes::Scalar, Psych::Nodes::Alias
          if node.is_a?(Psych::Nodes::Alias)
            print "*#{node.anchor}"
          else
            print Emitter.stringify_node(node, @indent)
          end
        when Psych::Nodes::Mapping
          if node.children.empty?
            print "{}"
            return
          end
          newline!
          node.children.each_slice(2) do |(key, value)|
            emit(key)
            print ":"
            space!
            if Emitter.single_line(value)
              emit(value)
            elsif Emitter.has_bullet(value)
              emit(value)
            else
              @indent += 1
              emit(value)
              @indent -= 1
            end
            newline!
          end
        when Psych::Nodes::Sequence
          if node.children.empty?
            print "[]"
            return
          end
          newline!
          node.children.each do |subnode|
            print "- "
            @state = :pseudo_indent
            @indent += 1
            emit(subnode)
            @indent -= 1
            newline!
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
    end

    private_constant :Emitter

    def self.emit_yaml(node)
      emitter = Emitter.new
      emitter.emit(node)
      emitter.out
    end
  end
end
