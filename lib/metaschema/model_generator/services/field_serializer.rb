# frozen_string_literal: true

require_relative "collapsibles_collapser"

module Metaschema
  class ModelGenerator
    module Services
      # Serializes a field value from a model instance to the target format.
      # Handles SINGLETON_OR_ARRAY normalization and collapsible field merging.
      #
      # Pipeline: transform -> make_collapsible -> serialize -> apply_value_map
      #           -> collapse -> denormalize
      class FieldSerializer
        def initialize(model, attr, format, data, group_as:, collapsible:)
          @model = model
          @attribute = model.class.attributes[attr]
          @format = format
          @mapping_rule = model.class.mappings[format].mappings
            .find { |r| r.to == attr }
          @data = data
          @group_as = group_as
          @collapsible = collapsible
        end

        def self.call(...)
          new(...).call
        end

        def call
          value = @model.public_send(@attribute.name)
          return if value.nil?

          value = transform(value)
          value = make_collapsible(value) if @collapsible
          value = serialize(value)
          return unless @mapping_rule&.render?(value, @model)

          value = apply_value_map(value)
          value = collapse(value) if @collapsible
          value = denormalize(value)

          @data[@mapping_rule.name] = value
        end

        private

        def transform(value)
          Lutaml::Model::ExportTransformer.call(value, @mapping_rule,
                                                @attribute)
        end

        def make_collapsible(value)
          collapsible_attrs = @attribute.type.attributes
            .reject { |_, attr| content_attribute?(attr) }
          @collapser = CollapsiblesCollapser.new(
            @attribute.type, collapsible_attrs, @format, value
          )
          @collapser.collapsibles
        end

        def content_attribute?(attr)
          attr.name == :content && attr.type < Lutaml::Model::Type::Value
        end

        def serialize(value)
          @attribute.serialize(value, @format, @model.lutaml_register)
        end

        def apply_value_map(value)
          if value.nil?
            value_for_option(value_map[:nil], @attribute)
          elsif Lutaml::Model::Utils.empty?(value)
            value_for_option(value_map[:empty], @attribute, value)
          elsif Lutaml::Model::Utils.uninitialized?(value)
            value_for_option(value_map[:omitted], @attribute)
          else
            value
          end
        end

        def value_map
          @mapping_rule.value_map(:to)
        end

        def value_for_option(option, attr, empty_value = nil)
          return nil if option == :nil
          return empty_value || empty_object(attr) if option == :empty

          Lutaml::Model::UninitializedClass.instance
        end

        def empty_object(attr)
          attr.collection? ? [] : ""
        end

        def collapse(value)
          @collapser.call(value)
        end

        def denormalize(value)
          soa = @group_as == "SINGLETON_OR_ARRAY"
          if soa && value.is_a?(Array) && value.one?
            value.first
          else
            value
          end
        end
      end
    end
  end
end
