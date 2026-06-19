# frozen_string_literal: true

module Metaschema
  # Bidirectional conversion between a parsed markup-line/markup-multiline
  # field instance (text content plus inline/block element collections,
  # ordered via lutaml-model's element_order) and an OSCAL-flavored Markdown
  # string. Generated markup field classes delegate their JSON/YAML
  # (de)serialization here so JSON/YAML carry a single Markdown string while
  # XML carries mixed inline elements.
  module MarkupConverter
    INLINE_ELEMENTS = %i[a insert br code em i b strong sub sup q img].freeze
    BLOCK_ELEMENTS = %i[p h1 h2 h3 h4 h5 h6 ul ol pre hr blockquote
                        table].freeze

    module_function

    def to_markdown(instance)
      return nil if instance.nil?

      blocks = ordered_block_children(instance)
      return render_blocks(blocks) unless blocks.empty?

      render_inline(instance)
    end

    # Blocks (p, h1-h6, ul, ol, ...) in original document order, recovered from
    # the parsed instance's element_order; falls back to attribute order. Any
    # block not referenced by element_order is appended (never dropped).
    def ordered_block_children(instance)
      queues = block_queues(instance)
      order = instance.respond_to?(:element_order) ? instance.element_order : nil
      return drain(queues) unless order

      ordered = order.filter_map { |node| shift_block(queues, node.name.to_sym) }
      ordered + drain(queues)
    end

    def shift_block(queues, name)
      return unless BLOCK_ELEMENTS.include?(name) && queues[name]&.any?

      [name, queues[name].shift]
    end

    def drain(queues)
      queues.flat_map { |name, items| items.map { |item| [name, item] } }
    end

    def block_queues(instance)
      BLOCK_ELEMENTS.each_with_object({}) do |name, queues|
        next unless instance.respond_to?(name)

        queues[name] = Array(instance.public_send(name)).dup
      end
    end

    def render_inline(instance)
      name_for = element_name_lookup(instance)
      out = +""
      instance.each_mixed_content do |item|
        out << if item.is_a?(String)
                 item
               else
                 render_mixed_child(name_for.fetch(item), item)
               end
      end
      out
    end

    # A list item (and other mixed containers) can hold block elements
    # interleaved with inline ones; dispatch each child to the right renderer.
    def render_mixed_child(name, child)
      if BLOCK_ELEMENTS.include?(name)
        render_block(name, child)
      else
        render_element(name, child)
      end
    end

    # each_mixed_content yields the same child objects stored in the element
    # collections, so object identity recovers which element a child came from.
    # Covers inline AND block names because containers such as listItemType mix
    # both.
    def element_name_lookup(instance)
      lookup = {}.compare_by_identity
      (INLINE_ELEMENTS + BLOCK_ELEMENTS).each do |name|
        next unless instance.respond_to?(name)

        Array(instance.public_send(name)).each { |child| lookup[child] = name }
      end
      lookup
    end

    def render_element(name, child)
      case name
      when :em, :i then "*#{render_inline(child)}*"
      when :strong, :b then "**#{render_inline(child)}**"
      when :q then %("#{render_inline(child)}")
      when :sub then "~#{render_inline(child)}~"
      when :sup then "^#{render_inline(child)}^"
      when :code then "`#{Array(child.content).join}`"
      when :br then "\n"
      when :a then "[#{Array(child.content).join}](#{child.href})"
      when :img then render_image(child)
      when :insert then "{{ insert: #{child.type}, #{child.id_ref} }}"
      end
    end

    def render_image(child)
      title = child.respond_to?(:title) ? child.title : nil
      suffix = title.nil? || title.empty? ? "" : %( "#{title}")
      "![#{child.alt}](#{child.src}#{suffix})"
    end

    def render_blocks(blocks)
      blocks.map { |name, child| render_block(name, child) }.join("\n\n")
    end

    def render_block(name, child)
      case name
      when :p then render_inline(child)
      when :h1, :h2, :h3, :h4, :h5, :h6
        "#{'#' * name.to_s[1].to_i} #{render_inline(child)}"
      when :hr then "---"
      when :ul then render_list(child, "- ")
      when :ol then render_list(child, "1. ")
      else
        # pre/blockquote are mixed-content; table (only <tr>) and any other block
        # type are not — render inline text only when the child supports it.
        render_block_fallback(child)
      end
    end

    def render_block_fallback(child)
      if child.respond_to?(:each_mixed_content) then render_inline(child)
      elsif child.respond_to?(:content) then Array(child.content).join
      else ""
      end
    end

    def render_list(list, marker)
      Array(list.li).map { |item| "#{marker}#{render_inline(item)}" }.join("\n")
    end

    # A URL may contain single-level balanced parens (e.g. a_(b)); match a run of
    # non-paren chars or balanced ( ... ) groups so the closing ) is not eaten early.
    URL = '(?:[^()\s]|\([^()]*\))+'

    # strong (**) is matched before em (*) so **x** is not split as *(*x*)*.
    INLINE_PATTERN = /
      (?<insert>\{\{\s*insert:\s*(?<ins_type>[^,]+?),\s*(?<ins_ref>[^}]+?)\s*\}\}) |
      (?<img>!\[(?<img_alt>[^\]]*)\]\((?<img_src>#{URL})(?:\s+"(?<img_title>[^"]*)")?\)) |
      (?<a>\[(?<a_text>[^\]]*)\]\((?<a_href>#{URL})\)) |
      (?<strong>\*\*(?<strong_in>.+?)\*\*) |
      (?<em>\*(?<em_in>.+?)\*) |
      (?<code>`(?<code_in>[^`]+)`) |
      (?<q>"(?<q_in>[^"]*)") |
      (?<sub>~(?<sub_in>[^~]+)~) |
      (?<sup>\^(?<sup_in>[^\s^]+)\^)
    /x

    def from_markdown(klass, string)
      instance = klass.new
      if multiline_class?(klass) && !string.to_s.strip.empty?
        apply_blocks(klass, instance, string.to_s)
      else
        apply_tokens(klass, instance, tokenize(string))
      end
      instance
    end

    def multiline_class?(klass)
      BLOCK_ELEMENTS.any? { |name| klass.attributes.key?(name) }
    end

    def apply_blocks(klass, instance, string)
      order = []
      collections = Hash.new { |h, k| h[k] = [] }

      split_blocks(string).each do |kind, payload|
        collections[kind] << build_block(klass, kind, payload)
        order << element_node(kind)
      end

      collections.each { |name, list| instance.public_send("#{name}=", list) }
      instance.element_order = order
      instance.mixed = true
      instance.ordered = true
    end

    def split_blocks(string)
      string.split(/\n{2,}/).filter_map do |raw|
        block = raw.strip
        next if block.empty?

        classify_block(block)
      end
    end

    def classify_block(block)
      if (m = block.match(/\A(#+)\s+(.*)\z/m))
        [:"h#{m[1].length}", m[2]]
      elsif block.match?(/\A---\s*\z/)
        [:hr, ""]
      elsif block.lines.all? { |l| l.match?(/\A\d+\.\s/) }
        [:ol, block]
      elsif block.lines.all? { |l| l.match?(/\A[-*]\s/) }
        [:ul, block]
      else
        [:p, block]
      end
    end

    def build_block(klass, kind, payload)
      type = klass.attributes[kind].type
      case kind
      when :ul then build_list(type, payload, /\A[-*]\s+/)
      when :ol then build_list(type, payload, /\A\d+\.\s+/)
      when :hr then type == :string || type.nil? ? "" : type.new
      else from_markdown(type, payload)
      end
    end

    # A list item holds its text as direct content (<li>text</li>), never
    # wrapped in <p>, so tokenize inline regardless of the item type being a
    # block-capable listItemType.
    def build_list(list_type, payload, marker)
      item_type = list_type.attributes[:li].type
      items = payload.lines.map do |line|
        item = item_type.new
        apply_tokens(item_type, item, tokenize(line.sub(marker, "").rstrip))
        item
      end
      list_type.new(li: items)
    end

    def tokenize(string)
      tokens = []
      pos = 0
      str = string.to_s
      while pos < str.length
        md = INLINE_PATTERN.match(str, pos)
        unless md
          tokens << [:text, str[pos..]]
          break
        end
        tokens << [:text, str[pos...md.begin(0)]] if md.begin(0) > pos
        tokens << token_for(md)
        pos = md.end(0)
      end
      tokens
    end

    def token_for(match)
      if match[:insert]
        [:insert, { type: match[:ins_type].strip, id_ref: match[:ins_ref].strip }]
      elsif match[:img]
        [:img, { alt: match[:img_alt], src: match[:img_src], title: match[:img_title] }]
      elsif match[:a]
        [:a, { content: match[:a_text], href: match[:a_href] }]
      elsif match[:strong] then [:strong, match[:strong_in]]
      elsif match[:em] then [:em, match[:em_in]]
      elsif match[:code] then [:code, { content: match[:code_in] }]
      elsif match[:q] then [:q, match[:q_in]]
      elsif match[:sub] then [:sub, match[:sub_in]]
      elsif match[:sup] then [:sup, match[:sup_in]]
      end
    end

    def apply_tokens(klass, instance, tokens)
      content = []
      order = []
      collections = Hash.new { |h, k| h[k] = [] }

      tokens.each do |kind, payload|
        if kind == :text
          content << payload
          order << text_node(payload)
        else
          collections[kind] << build_child(klass, kind, payload)
          order << element_node(kind)
        end
      end

      instance.content = content
      collections.each { |name, list| instance.public_send("#{name}=", list) }
      instance.element_order = order
      instance.mixed = true
      instance.ordered = true
    end

    def build_child(klass, name, payload)
      type = klass.attributes[name].type
      case name
      when :em, :i, :strong, :b, :q, :sub, :sup
        from_markdown(type, payload)
      when :a then type.new(content: [payload[:content]], href: payload[:href])
      when :code then type.new(content: [payload[:content]])
      when :insert then type.new(type: payload[:type], id_ref: payload[:id_ref])
      when :img then type.new(alt: payload[:alt], src: payload[:src],
                              title: payload[:title])
      end
    end

    def text_node(text)
      Lutaml::Xml::Element.new("Text", "text", text_content: text,
                                               node_type: :text)
    end

    def element_node(name)
      Lutaml::Xml::Element.new("Element", name.to_s, node_type: :element)
    end
  end
end
