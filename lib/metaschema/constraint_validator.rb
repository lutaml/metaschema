# frozen_string_literal: true

module Metaschema
  class ConstraintValidator
    attr_reader :errors

    def initialize
      @errors = []
    end

    # Validate a generated class instance against its metaschema constraints.
    # Returns an array of ConstraintError objects.
    def validate(instance, constraint_def)
      @errors = []
      return @errors unless constraint_def

      validate_allowed_values(instance, constraint_def)
      validate_matches(instance, constraint_def)
      if constraint_def.respond_to?(:has_cardinality)
        validate_has_cardinality(instance,
                                 constraint_def)
      end
      if constraint_def.respond_to?(:is_unique)
        validate_is_unique(instance,
                           constraint_def)
      end
      if constraint_def.respond_to?(:expect)
        validate_expect(instance,
                        constraint_def)
      end
      if constraint_def.respond_to?(:index_has_key)
        validate_index_has_key(instance,
                               constraint_def)
      end

      @errors
    end

    # Recursively validate an entire instance tree.
    # Validates each node's own constraints, then recurses into children.
    def self.validate_tree(instance)
      errors = []

      if instance.is_a?(Lutaml::Model::Serializable)
        # Validate this instance's own constraints
        if instance.respond_to?(:validate_constraints)
          errors.concat(instance.validate_constraints)
        end

        # Validate occurrence constraints (min/max-occurs)
        if instance.respond_to?(:validate_occurrences)
          errors.concat(instance.validate_occurrences)
        end

        # Recurse into all attribute values
        instance.class.attributes.each_key do |attr_name|
          value = instance.send(attr_name)
          next if value.nil?

          if value.is_a?(Array)
            value.each { |v| errors.concat(validate_tree(v)) if v.is_a?(Lutaml::Model::Serializable) }
          elsif value.is_a?(Lutaml::Model::Serializable)
            errors.concat(validate_tree(value))
          end
        end
      end

      errors
    end

    private

    # ── allowed-values ────────────────────────────────────────────────

    def validate_allowed_values(instance, constraint_def)
      constraints = Array(constraint_def.allowed_values)
      constraints.each do |c|
        target = c.target || "."
        values = resolve_target_values(instance, target)
        allowed = Array(c.enum).filter_map(&:value)
        allow_other = c.allow_other == "yes"
        level = c.level || "ERROR"

        values.each do |val|
          next if val.nil? || val.to_s.empty?
          next if allow_other
          next if allowed.include?(val.to_s)

          @errors << ConstraintError.new(
            constraint_type: :allowed_values,
            level: level,
            message: "Value '#{val}' not in allowed values: #{allowed.join(', ')}",
            target: target,
          )
        end
      end
    end

    # ── matches ───────────────────────────────────────────────────────

    def validate_matches(instance, constraint_def)
      constraints = Array(constraint_def.matches)
      constraints.each do |c|
        target = c.target || "."
        values = resolve_target_values(instance, target)
        level = c.level || "ERROR"

        values.each do |val|
          next if val.nil? || val.to_s.empty?

          if c.regex
            unless val.to_s.match?(Regexp.new(c.regex))
              @errors << ConstraintError.new(
                constraint_type: :matches,
                level: level,
                message: "Value '#{val}' does not match regex '#{c.regex}'",
                target: target,
              )
            end
          elsif c.datatype
            unless datatype_matches?(val, c.datatype)
              @errors << ConstraintError.new(
                constraint_type: :matches,
                level: level,
                message: "Value '#{val}' does not match datatype '#{c.datatype}'",
                target: target,
              )
            end
          end
        end
      end
    end

    # ── has-cardinality ──────────────────────────────────────────────

    def validate_has_cardinality(instance, constraint_def)
      constraints = Array(constraint_def.has_cardinality)
      constraints.each do |c|
        target = c.target || "."
        level = c.level || "ERROR"
        count = count_target_items(instance, target)

        if c.min_occurs && count < c.min_occurs
          @errors << ConstraintError.new(
            constraint_type: :has_cardinality,
            level: level,
            message: "Expected at least #{c.min_occurs} items at '#{target}', got #{count}",
            target: target,
          )
        end

        if c.max_occurs && c.max_occurs != "unbounded" && count > c.max_occurs.to_i
          @errors << ConstraintError.new(
            constraint_type: :has_cardinality,
            level: level,
            message: "Expected at most #{c.max_occurs} items at '#{target}', got #{count}",
            target: target,
          )
        end
      end
    end

    # ── is-unique ────────────────────────────────────────────────────

    def validate_is_unique(instance, constraint_def)
      constraints = Array(constraint_def.is_unique)
      constraints.each do |c|
        target = c.target || "."
        level = c.level || "ERROR"
        key_fields = Array(c.key_field).map(&:target)

        items = resolve_target_collection(instance, target)
        next unless items.is_a?(Array) && items.length > 1

        # Build key tuples for each item
        seen = {}
        items.each_with_index do |item, idx|
          key = if key_fields.empty?
                  extract_value(item)
                else
                  key_fields.map do |kf|
                    resolve_flag_value(item, kf)
                  end
                end
          key_str = Array(key).join("|")

          if seen.key?(key_str)
            @errors << ConstraintError.new(
              constraint_type: :is_unique,
              level: level,
              message: "Duplicate key '#{key_str}' at '#{target}' (items #{seen[key_str]} and #{idx})",
              target: target,
            )
          else
            seen[key_str] = idx
          end
        end
      end
    end

    # ── expect ───────────────────────────────────────────────────────

    def validate_expect(_instance, constraint_def)
      # expect constraints use XPath test expressions which are complex
      # to evaluate without a full XPath engine. Log as WARNING for now.
      constraints = Array(constraint_def.expect)
      constraints.each do |c|
        # Future: evaluate c.test against instance
      end
    end

    # ── index-has-key ────────────────────────────────────────────────

    def validate_index_has_key(_instance, constraint_def)
      # index-has-key requires an index registry which is complex.
      # Stub for now.
      constraints = Array(constraint_def.index_has_key)
      constraints.each do |c|
        # Future: look up index by c.name and validate keys
      end
    end

    # ── Target Resolution ────────────────────────────────────────────

    # Resolve a Metaschema target expression to values from an instance.
    # Delegates to MetapathEvaluator for complex expressions.
    def resolve_target_values(instance, target)
      return [extract_value(instance)] if target == "."

      # Use MetapathEvaluator for complex patterns
      if complex_target?(target)
        evaluator = MetapathEvaluator.new(instance)
        return evaluator.resolve(target)
      end

      # .//name — descendant search
      if target.start_with?(".//")
        path = target[3..]
        return resolve_descendant_values(instance, path)
      end

      # .[@flag='value']/rest — conditional
      if target.start_with?(".[@") && target.include?("]/")
        return resolve_conditional_path(instance, target)
      end

      # @flag-name — flag value
      if target.start_with?("@")
        flag_name = target[1..].gsub("-", "_")
        return [resolve_flag_value(instance, flag_name)]
      end

      # field-name — child field value
      [resolve_child_value(instance, target)]
    end

    # Determine if a target expression requires MetapathEvaluator.
    def complex_target?(target)
      target.include?("has-oscal-namespace") ||
        target.include?("starts-with") ||
        target.include?(" and ") ||
        target.include?(" or ") ||
        target.include?("(.)") ||
        target.match?(/\w+\[.*\]/) ||
        (target.include?("/@") && !target.start_with?(".[@"))
    end

    # Count items at a target path (for cardinality checks).
    def count_target_items(instance, target)
      if complex_target?(target)
        evaluator = MetapathEvaluator.new(instance)
        items = evaluator.resolve_collection(target)
        return items.compact.length
      end

      return 1 unless target.include?("/") || target.start_with?(".")

      # Handle conditional paths like ".[@type='quatrain']/line"
      if target.start_with?(".[@") && target.include?("]/")
        filter_attr, filter_val, rest = parse_conditional(target)
        flag_val = resolve_flag_value(instance, filter_attr)
        return 0 unless flag_val.to_s == filter_val

        child_name = rest.gsub("-", "_").to_sym
        child = get_child(instance, child_name)
        return 0 unless child
        return child.length if child.is_a?(Array)

        return 1
      end

      # .//name — count all descendants
      if target.start_with?(".//")
        path = target[3..]
        values = resolve_descendant_values(instance, path)
        return values.length
      end

      0
    end

    # Resolve a collection of items at a target path (for uniqueness checks).
    def resolve_target_collection(instance, target)
      return [instance] if target == "."

      if complex_target?(target)
        evaluator = MetapathEvaluator.new(instance)
        return evaluator.resolve_collection(target)
      end

      # Simple child name
      child_name = target.gsub("-", "_").to_sym
      child = get_child(instance, child_name)
      return child if child.is_a?(Array)

      child ? [child] : []
    end

    def extract_value(item)
      return item unless item.is_a?(Lutaml::Model::Serializable)

      # Try common value attributes
      if item.respond_to?(:content)
        val = item.content
        return val unless using_default?(item, :content)
      end

      item
    end

    def resolve_flag_value(instance, flag_name)
      return instance unless instance.is_a?(Lutaml::Model::Serializable)

      sym = flag_name.to_s.gsub("-", "_").to_sym
      return instance.send(sym) if instance.respond_to?(sym)

      nil
    end

    def resolve_child_value(instance, child_name)
      return instance unless instance.is_a?(Lutaml::Model::Serializable)

      sym = child_name.to_s.gsub("-", "_").to_sym
      child = get_child(instance, sym)
      return extract_value(child) if child

      nil
    end

    def resolve_descendant_values(instance, path)
      # Simplified: split path and search recursively
      parts = path.split("/")
      collect_descendants(instance, parts)
    end

    def collect_descendants(instance, parts)
      return [] unless instance.is_a?(Lutaml::Model::Serializable)

      current_name = parts[0].gsub("-", "_").to_sym
      rest = parts[1..]

      child = get_child(instance, current_name)
      return [] unless child

      items = child.is_a?(Array) ? child : [child]

      if rest.empty?
        items.map { |i| extract_value(i) }
      else
        items.flat_map { |i| collect_descendants(i, rest) }
      end
    end

    def resolve_conditional_path(instance, target)
      filter_attr, filter_val, rest = parse_conditional(target)

      flag_val = resolve_flag_value(instance, filter_attr)
      return [] unless flag_val.to_s == filter_val

      resolve_target_values(instance, rest)
    end

    def parse_conditional(target)
      # Parse ".[@attr='value']/rest"
      m = target.match(/\.\[@(\w+)(?:-\w+)*='([^']+)'\]\/(.+)/)
      return [nil, nil, target] unless m

      m[1..].first # raw attr including hyphens
      # Re-extract properly
      match = target.match(/\.\[@([\w-]+)='([^']+)'\]\/(.+)/)
      [match[1].gsub("-", "_"), match[2], match[3]]
    end

    def get_child(instance, sym)
      return nil unless instance.respond_to?(sym)

      instance.send(sym)
    end

    def using_default?(instance, attr_name)
      instance.respond_to?(:using_default?) && instance.using_default?(attr_name)
    rescue NoMethodError
      false
    end

    def datatype_matches?(value, datatype)
      case datatype
      when "string" then true
      when "integer", "int" then value.to_s.match?(/\A-?\d+\z/)
      when "positive-integer" then value.to_s.match?(/\A[1-9]\d*\z/)
      when "boolean" then ["true", "false", "1", "0"].include?(value.to_s)
      when "date" then value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      when "datetime" then value.to_s.match?(/\A\d{4}-\d{2}-\d{2}T/)
      when "uri" then value.to_s.match?(/\A[a-zA-Z][a-zA-Z0-9+\-.]*:/)
      when "uuid" then value.to_s.match?(/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-/)
      else true # Unknown datatype, pass by default
      end
    end

    # Validate min/max occurrence constraints on an instance.
    # occurrence_constraints is a Hash of {attr_name => {min: N, max: N}}
    def self.validate_occurrences(instance, occurrence_constraints)
      errors = []
      return errors unless occurrence_constraints && !occurrence_constraints.empty?

      occurrence_constraints.each do |attr_name, constraints|
        value = instance.respond_to?(attr_name) ? instance.send(attr_name) : nil
        count = case value
                when nil then 0
                when Array then value.length
                else 1
                end

        min = constraints[:min]
        max = constraints[:max]

        if min&.positive? && count < min
          errors << ConstraintError.new(
            constraint_type: :occurrence,
            level: "ERROR",
            message: "Expected at least #{min} '#{attr_name}', got #{count}",
            target: attr_name.to_s,
          )
        end

        if max && count > max
          errors << ConstraintError.new(
            constraint_type: :occurrence,
            level: "ERROR",
            message: "Expected at most #{max} '#{attr_name}', got #{count}",
            target: attr_name.to_s,
          )
        end
      end

      errors
    end

    # Simple wrapper for constraint error info
    class ConstraintError
      attr_reader :constraint_type, :level, :message, :target

      def initialize(constraint_type:, level:, message:, target:)
        @constraint_type = constraint_type
        @level = level
        @message = message
        @target = target
      end

      def to_s
        "[#{level}] #{constraint_type}: #{message} (target: #{target})"
      end

      def error?
        level == "ERROR"
      end

      def warning?
        level == "WARNING"
      end
    end
  end
end
