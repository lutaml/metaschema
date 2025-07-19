# frozen_string_literal: true

module Metaschema
  module Factory
    module Utils
      # NOTE: This is just to visualize model created in the factory and may not
      #   be 100% accurate.
      class ModelToRuby # rubocop:disable Metrics/ClassLength
        def initialize(model)
          @model = model
        end

        def call
          @lines = []
          process_model
          @lines.join
        end
        alias to_s call

        private

        def process_model
          add "class #{@model} < #{@model.superclass}"

          process_attributes
          process_mappings
          process_custom_methods

          add 'end'
        end

        def add(line)
          @lines << "#{line}\n"
        end

        def prev_line_start_with?(*args)
          @lines.last&.start_with?(*args)
        end

        # == Attributes

        def process_attributes
          @model.attributes.each_value do |attr|
            choice = attr.options[:choice]

            if choice.nil?
              process_attribute(attr, 1)
            elsif choice.attributes.first == attr && @model.choice_attributes.include?(choice)
              process_choice(choice, 1)
            end
          end
        end

        def process_attribute(attr, deep = 0)
          type = attr.unresolved_type.inspect
          opts = attr.options

          if collection_instances?(attr)
            opts = opts.except(:collection, :validations)
            add "#{'  ' * deep}instances #{attr.name.inspect}, #{type}#{inspect_kwargs(opts, ', ')}"
          else
            opts = opts.except(:choice)
            add "#{'  ' * deep}attribute #{attr.name.inspect}, #{type}#{inspect_kwargs(opts, ', ')}"
          end
        end

        def collection_instances?(attr)
          opts = attr.options

          @model < Lutaml::Model::Collection &&
            opts[:collection] == true &&
            opts.key?(:validations) &&
            opts[:validations].then { |n| n.nil? || n.is_a?(Proc) } &&
            @model.method_defined?(:"#{attr.name}=", false)
        end

        def inspect_kwargs(kwargs, prefix = nil)
          return if kwargs.empty?

          "#{prefix}#{inspect_hash(kwargs)[2..-3]}"
        end

        def inspect_hash(hash)
          return hash.inspect if hash.empty?

          string =
            hash
            .map do |k, v|
              k = k.is_a?(Symbol) ? "#{k.inspect[1..]}:" : "#{inspect_object(k)} =>"
              v = inspect_object(v)
              "#{k} #{v}"
            end
            .join(', ')
          "{ #{string} }"
        end

        def inspect_object(object)
          return inspect_hash(object) if object.instance_of?(Hash)

          object.inspect
        end

        def process_choice(choice, deep = 0) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          opts = {}
          opts[:min] = choice.min if choice.min != 1
          opts[:max] = choice.max if choice.max != 1
          add "#{'  ' * deep}choice#{inspect_kwargs(opts, ' ')} do"

          next_deep = deep.next
          choice.attributes.each do |attr|
            if attr.is_a?(Lutaml::Model::Choice)
              process_choice(attr, next_deep)
            else
              process_attribute(attr, next_deep)
            end
          end

          add "#{'  ' * deep}end"
        end

        # == Mappings

        def process_mappings
          @model.mappings.each_key do |format|
            send :"process_#{format}_mapping"
          end
        end

        # === JSON mapping

        def process_json_mapping
          add '' if prev_line_start_with?('  ')
          add '  json do'

          process_json_root

          add '' if prev_line_start_with?('    ') && json_mapping.mappings.any?

          process_json_mappings

          add '  end'
        end

        def process_json_root
          if json_mapping.root_name
            add "    root #{json_mapping.root_name.inspect}"
          elsif json_mapping.instance_variable_defined?(:@root)
            add '    no_root'
          end
        end

        def json_mapping
          @model.mappings.fetch(:json)
        end

        def process_json_mappings
          process_json_key_value_mappings
          process_json_main_mappings
        end

        def process_json_key_value_mappings
          json_mapping.key_value_mappings.each do |name, rule|
            opts = { to_instance: rule.to_instance, as_attribute: rule.as_attribute }.compact
            add "    map_#{name}#{inspect_kwargs(opts, ' ')}"
          end
        end

        def process_json_main_mappings # rubocop:disable Metrics/AbcSize
          json_mapping.mappings.each do |rule|
            if rule.name == (json_mapping.root_name || rule.to)
              opts = { to: rule.to }.compact
              add "    map_instances#{inspect_kwargs(opts, ' ')}"
            else
              opts = json_mapping_map_kwargs_for(rule)
              add "    map #{rule.name.inspect}#{inspect_kwargs(opts, ', ')}"
            end
          end
        end

        def json_mapping_map_kwargs_for(rule)
          hash_difference(json_mapping_map_kwargs_from(rule), default_json_mapping_map_kwargs)
        end

        def hash_difference(left, right) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          hash = left.dup
          hash.each do |key, value|
            if right.is_a?(Hash) && right.key?(key)
              right_value = right[key]
              if value.is_a?(Hash)
                value = hash[key] = hash_difference(value, right_value)
                hash.delete(key) if value.empty?
              elsif value == right_value
                hash.delete(key)
              end
            elsif value.is_a?(Hash)
              hash[key] = hash_difference(value, nil)
            end
          end
          hash
        end

        def json_mapping_map_kwargs_from(rule) # rubocop:disable Metrics/MethodLength
          {
            to: rule.to,
            render_nil: rule.render_nil,
            render_default: rule.render_default,
            render_empty: rule.render_empty,
            treat_nil: rule.treat_nil,
            treat_empty: rule.treat_empty,
            treat_omitted: rule.treat_omitted,
            with: rule.custom_methods,
            delegate: rule.delegate,
            child_mappings: rule.child_mappings,
            root_mappings: rule.root_mappings,
            polymorphic: rule.polymorphic,
            polymorphic_map: rule.polymorphic_map,
            transform: rule.transform,
            value_map: hash_difference(rule.instance_variable_get(:@value_map), rule.default_value_map)
          }
        end

        def default_json_mapping_map_kwargs # rubocop:disable Metrics/MethodLength
          {
            to: nil,
            render_nil: false,
            render_default: false,
            render_empty: false,
            treat_nil: nil,
            treat_empty: nil,
            treat_omitted: nil,
            with: {},
            delegate: nil,
            child_mappings: nil,
            root_mappings: nil,
            polymorphic: {},
            polymorphic_map: {},
            transform: {},
            value_map: {}
          }
        end

        # === XML mapping

        def process_xml_mapping
          add '' if prev_line_start_with?('  ')
          add '  xml do'

          process_xml_root
          process_xml_namespace

          add '' if prev_line_start_with?('    ') && xml_mapping.mappings.any?

          process_xml_attribute_mappings
          process_xml_content_mapping
          process_xml_element_mappings

          add '  end'
        end

        def process_xml_root
          if xml_mapping.root?
            opts = {}
            opts[xml_mapping.mixed_content? ? :mixed : :ordered] = true if xml_mapping.ordered?
            add "    root #{xml_mapping.root_element.inspect}#{inspect_kwargs(opts, ', ')}"
          elsif xml_mapping.no_root?
            add '    no_root'
          end
        end

        def xml_mapping
          @model.mappings.fetch(:xml)
        end

        def process_xml_namespace
          namespace = xml_mapping.namespace_uri
          return if namespace.nil?

          prefix = xml_mapping.namespace_prefix
          add "    namespace #{namespace.inspect}#{", #{prefix.inspect}" if prefix}"
        end

        def process_xml_attribute_mappings
          xml_mapping.attributes.each do |rule|
            opts = { to: rule.to, delegate: rule.delegate }.compact
            add "    map_attribute #{rule.name.inspect}#{inspect_kwargs(opts, ', ')}"
          end
        end

        def process_xml_content_mapping
          rule = xml_mapping.content_mapping
          return if rule.nil?

          opts = { to: rule.to, delegate: rule.delegate }.compact
          add "    map_content#{inspect_kwargs(opts, ' ')}"
        end

        def process_xml_element_mappings
          xml_mapping.elements.each do |rule|
            opts = { to: rule.to, delegate: rule.delegate }.compact

            if rule.name == rule.to && !opts.key?(:delegate)
              add "    map_instances#{inspect_kwargs(opts, ' ')}"
            else
              add "    map_element #{rule.name.inspect}#{inspect_kwargs(opts, ', ')}"
            end
          end
        end

        # == Custom methods

        def process_custom_methods
          process_json_custom_methods
        end

        # === JSON custom methods

        def process_json_custom_methods
          json_mapping.mappings.each do |rule|
            process_json_custom_methods_for(rule)
          end
        end

        def process_json_custom_methods_for(rule)
          process_custom_method_for(rule, :to, :json)
          process_custom_method_for(rule, :from, :json)
        end

        def process_custom_method_for(rule, dir, format)
          name = rule.custom_methods[dir]
          return if name.nil?

          code = method_expression(@model.instance_method(name))
          return if code.nil?

          code = gsub_expression(code, { attr: rule.to, format: format })
          code = simplify_method_expression(code)

          add '' if prev_line_start_with?('  ')
          code.each_line chomp: true do |line|
            add "  #{line}"
          end
        end

        def gsub_expression(code, vars)
          code.gsub(
            /#{vars.each_key.map { |n| "\\\#{#{n}}|\\b#{n}\\b" }.join('|')}/,
            vars.each_with_object({}) do |(k, v), h|
              h["\#{#{k}}"] = v.to_s
              h[k.to_s] = v.inspect
            end
          )
        end

        def method_expression(method)
          file, line = method.source_location
          return if file.nil?

          lines = File.readlines(file, chomp: true)[line.pred..]
          indentation = Regexp.escape(lines.first[/^[\t ]*/])
          ending = /^#{indentation}(?=\S)/
          code = lines[0..(lines[1..].index { |n| ending.match?(n) }&.next)].join("\n")
          code.gsub!(/^#{indentation}/, '')
          code
        end

        def simplify_method_expression(code)
          code = code.dup
          code.sub!(/\S.*?\.(?=define_method\b)/, '')
          code.gsub!(/(?<=:)"(\w+=?)"/, '\1')
          code
        end
      end
    end
  end
end
