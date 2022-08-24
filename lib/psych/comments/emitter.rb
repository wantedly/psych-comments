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
        if node.tag
          if node.style == Psych::Nodes::Scalar::PLAIN
            node2.plain = true
          else
            node2.quoted = true
          end
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
    # private_constant :NodeUtils

    class Emitter
      include NodeUtils

      INDENT = "  "

      DEFAULT_TAGMAP = {
        '!' => '!',
        '!!' => 'tag:yaml.org,2002:',
      }.freeze

      attr_reader :out

      def initialize
        @out = ""
        @state = :init
        @indent = 0
        @flow = false
        @comment_lookahead = []
        @tagmap = DEFAULT_TAGMAP
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
        if node.tag
          handle, suffix = decompose_tag(node.tag)
          if suffix
            print "#{handle}#{suffix}"
          else
            print "!<#{node.tag}>"
          end
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
          node.tag_directives.each do |(handle, prefix)|
            newline!
            print "%TAG #{handle} #{prefix}"
            newline!
          end
          unless node.implicit
            newline!
            print "---"
            newline!
          end
          set_tagmap(node) do
            emit(node.root)
          end
          unless node.implicit_end
            newline!
            print "..."
            newline!
          end
        when Psych::Nodes::Stream
          node.children.each do |subnode|
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

      # @param tag [String]
      def decompose_tag(tag)
        @tagmap.each do |handle, prefix|
          if tag.start_with?(prefix)
            suffix = tag.delete_prefix(prefix)
            if /\A(?:%[0-9a-fA-F]{2}|[-0-9a-z#;\/?:@&=+$_.~*'()])*\z/.match?(suffix)
              return [handle, suffix]
            end
          end
        end
        [nil, nil]
      end

      # @param node [Psych::Nodes::Document]
      def set_tagmap(node, &block)
        new_tagmap = DEFAULT_TAGMAP.dup
        node.tag_directives.each do |(handle, prefix)|
          new_tagmap[handle] = prefix
        end
        old_tagmap, @tagmap = @tagmap, new_tagmap
        begin
          block.()
        ensure
          @tagmap = old_tagmap
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
