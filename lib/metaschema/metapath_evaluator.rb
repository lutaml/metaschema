# frozen_string_literal: true

module Metaschema
  # Evaluates Metapath (XPath subset) expressions against Ruby object instances.
  #
  # Supported patterns (covering OSCAL constraint targets):
  #   "."                                  — current instance
  #   "@flag-name"                         — flag value
  #   "child-name"                         — child field value
  #   "child-name/@attr"                   — child's flag value
  #   "//descendant"                       — descendant values
  #   "child[@attr='val']"                 — filtered children
  #   "child[@attr='val']/@attr2"          — filtered child's attribute
  #   "child[func(...)]/@attr"             — function-based filter
  #   ".[condition]/path"                  — conditional navigation
  #   ".[condition]"                       — filter current instance
  #   "(.)[condition]/path"                — parenthesized self with filter
  #
  # Supported predicate functions:
  #   has-oscal-namespace('uri')           — checks prop/element ns attribute
  #   starts-with(@attr, 'prefix')         — string prefix check
  #
  # Supported predicate operators:
  #   @attr='value'                        — attribute equals
  #   @attr=('v1','v2',...)                — attribute in set
  #   and / or                             — logical operators
  #
  class MetapathEvaluator
    OSCAL_NS = "http://csrc.nist.gov/ns/oscal"

    attr_reader :context

    def initialize(context)
      @context = context
    end

    # Resolve a Metapath expression to values from the context instance.
    # Returns an array of values.
    def resolve(path)
      return [extract_value(@context)] if path == "."

      path = normalize_path(path)
      steps = parse_steps(path)
      evaluate_steps(@context, steps)
    end

    # Resolve a path to a collection of items (for uniqueness/cardinality checks).
    def resolve_collection(path)
      path = normalize_path(path)
      steps = parse_steps(path)
      evaluate_steps_collection(@context, steps)
    end

    private

    # Normalize path patterns
    def normalize_path(path)
      # (.)[pred]/rest → .[pred]/rest
      path.sub(/\A\(\.\)/, ".")
      # // at start → descendant::
    end

    # Parse a Metapath expression into evaluation steps.
    def parse_steps(path)
      steps = []
      remaining = path

      while remaining && !remaining.empty?
        # descendant-or-self //name
        if remaining.start_with?(".//")
          remaining = remaining[3..]
          name, rest = split_step(remaining)
          steps << { type: :descendant, name: name }
          remaining = rest
          next
        end

        # .[predicate]/rest
        if remaining.start_with?(".[")
          pred, rest = extract_predicate_block(remaining[1..])
          inner_rest = extract_after_predicate(rest)
          steps << { type: :filter_self, predicate: pred }
          remaining = inner_rest
          next
        end

        # @attr — attribute access
        if remaining.start_with?("@")
          name, rest = split_step(remaining[1..])
          steps << { type: :attribute, name: name }
          remaining = rest
          next
        end

        # child[predicate]/@attr — filtered child
        if remaining.match?(/\A[\w-]+\[/)
          m = remaining.match(/\A([\w-]+)\[/)
          child_name = m[1]
          pred, rest = extract_predicate_block(remaining[m[1].length..])
          steps << { type: :filtered_child, name: child_name, predicate: pred }
          remaining = extract_after_predicate(rest)
          next
        end

        # child-name — simple child access
        if remaining.match?(/\A[\w-]+/)
          name, rest = split_step(remaining)
          steps << { type: :child, name: name }
          remaining = rest
          next
        end

        # Skip unrecognized prefix
        remaining = remaining[1..]
      end

      steps
    end

    # Evaluate parsed steps against a context instance.
    def evaluate_steps(context, steps)
      return [extract_value(context)] if steps.empty?

      current_items = [context]

      steps.each do |step|
        next_items = []
        current_items.each do |item|
          next_items.concat(evaluate_step(item, step))
        end
        current_items = next_items
      end

      current_items
    end

    def evaluate_steps_collection(context, steps)
      return [context] if steps.empty?

      current_items = [context]

      steps.each do |step|
        next_items = []
        current_items.each do |item|
          case step[:type]
          when :child
            children = get_children(item, step[:name])
            next_items.concat(children)
          when :descendant
            next_items.concat(find_descendants(item, step[:name]))
          when :attribute
            next_items << resolve_attr(item, step[:name])
          when :filtered_child
            children = get_children(item, step[:name])
            filtered = children.select do |c|
              evaluate_predicate(c, step[:predicate])
            end
            next_items.concat(filtered)
          when :filter_self
            if evaluate_predicate(item, step[:predicate])
              next_items << item
            end
          else
            next_items << item
          end
        end
        current_items = next_items
      end

      current_items
    end

    def evaluate_step(item, step)
      case step[:type]
      when :attribute
        [resolve_attr(item, step[:name])]
      when :child
        children = get_children(item, step[:name])
        children.map { |c| extract_value(c) }
      when :descendant
        find_descendants(item, step[:name]).map { |d| extract_value(d) }
      when :filtered_child
        children = get_children(item, step[:name])
        children.select { |c| evaluate_predicate(c, step[:predicate]) }
      when :filter_self
        evaluate_predicate(item, step[:predicate]) ? [item] : []
      else
        [item]
      end
    end

    # ── Predicate Evaluation ──────────────────────────────────────────

    def evaluate_predicate(item, predicate)
      return true unless predicate

      # Handle "and" operators (simple split)
      if predicate.include?(" and ")
        parts = split_logical(predicate, " and ")
        return parts.all? { |p| evaluate_single_predicate(item, p.strip) }
      end

      # Handle "or" operators
      if predicate.include?(" or ")
        parts = split_logical(predicate, " or ")
        return parts.any? { |p| evaluate_single_predicate(item, p.strip) }
      end

      evaluate_single_predicate(item, predicate)
    end

    def evaluate_single_predicate(item, pred)
      pred = pred.strip

      # @attr='value' — simple attribute equals
      if (m = pred.match(/\A@([\w-]+)\s*=\s*'([^']+)'\z/))
        attr_val = resolve_attr(item, m[1])
        return attr_val.to_s == m[2]
      end

      # @attr=('v1','v2',...) — value in set
      if (m = pred.match(/\A@([\w-]+)\s*=\s*\(([^)]+)\)\z/))
        attr_val = resolve_attr(item, m[1])
        values = m[2].scan(/'([^']+)'/).flatten
        return values.include?(attr_val.to_s)
      end

      # has-oscal-namespace('uri') — check ns attribute against OSCAL namespace
      if (m = pred.match(/\Ahas-oscal-namespace\(\s*'([^']+)'\s*\)\z/))
        ns_uri = m[1]
        ns_val = resolve_attr(item, "ns")
        return ns_val.to_s == ns_uri || (ns_uri == OSCAL_NS && (ns_val.nil? || ns_val.to_s.empty?))
      end

      # starts-with(@attr, 'prefix') — string prefix check
      if (m = pred.match(/\Astarts-with\(\s*@([\w-]+)\s*,\s*'([^']+)'\s*\)\z/))
        attr_val = resolve_attr(item, m[1])
        return attr_val.to_s.start_with?(m[2])
      end

      # Combining functions with @attr='val' using 'and'
      if pred.include?(" and ")
        parts = split_logical(pred, " and ")
        return parts.all? { |p| evaluate_single_predicate(item, p.strip) }
      end

      false
    end

    # ── Instance Navigation ───────────────────────────────────────────

    def resolve_attr(instance, attr_name)
      return instance unless instance.is_a?(Lutaml::Model::Serializable)

      sym = attr_name.gsub("-", "_").to_sym
      return instance.send(sym) if instance.respond_to?(sym)

      nil
    end

    def get_children(instance, child_name)
      return [] unless instance.is_a?(Lutaml::Model::Serializable)

      sym = child_name.gsub("-", "_").to_sym
      return [] unless instance.respond_to?(sym)

      child = instance.send(sym)
      case child
      when Array then child
      when nil then []
      else [child]
      end
    end

    def find_descendants(instance, name)
      results = []
      return results unless instance.is_a?(Lutaml::Model::Serializable)

      sym = name.gsub("-", "_").to_sym

      instance.class.attributes.each_key do |attr_name|
        value = instance.send(attr_name)
        next if value.nil?

        items = value.is_a?(Array) ? value : [value]
        items.each do |item|
          next unless item.is_a?(Lutaml::Model::Serializable)

          if attr_name == sym
            results << item
          end

          results.concat(find_descendants(item, name))
        end
      end

      results
    end

    def extract_value(item)
      return item unless item.is_a?(Lutaml::Model::Serializable)
      return item.content if item.respond_to?(:content) && item.content

      item
    end

    # ── Parsing Helpers ───────────────────────────────────────────────

    def split_step(path)
      idx = path.index("/")
      idx ? [path[0...idx], path[(idx + 1)..]] : [path, nil]
    end

    def extract_predicate_block(str)
      # str starts with "[..."
      depth = 0
      i = 0
      while i < str.length
        case str[i]
        when "["
          depth += 1
        when "]"
          depth -= 1
          return [str[1...i], str[(i + 1)..]] if depth.zero?
        when "'"
          # Skip string literal
          i += 1
          while i < str.length && str[i] != "'"
            i += 1
          end
        end
        i += 1
      end
      [str[1..], ""]
    end

    def extract_after_predicate(rest)
      return nil unless rest

      rest.start_with?("/") ? rest[1..] : rest
    end

    # Split on logical operators respecting parentheses and quotes
    def split_logical(expr, op)
      parts = []
      depth = 0
      current = +""
      i = 0
      in_string = false

      while i < expr.length
        ch = expr[i]

        if ch == "'" && depth >= 0
          in_string = !in_string
          current << ch
          i += 1
          next
        end

        unless in_string
          case ch
          when "(", "["
            depth += 1
          when ")", "]"
            depth -= 1
          end

          if depth.zero? && expr[i, op.length + 2] == " #{op} "
            parts << current.strip
            current = +""
            i += op.length + 2
            next
          end
        end

        current << ch
        i += 1
      end

      parts << current.strip
      parts
    end
  end
end
