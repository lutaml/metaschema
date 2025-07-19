# frozen_string_literal: true

require 'lutaml/model'

require_relative '../field_factory'
require_relative 'collapsibles_collapser'

module Metaschema
  module Factory
    class FieldSerializer
      def initialize(model, attr, format, data, group_as:, collapsible:) # rubocop:disable Metrics/ParameterLists
        @model = model
        @attribute = model.class.attributes[attr]
        @format = format
        @mapping_rule = model.class.mappings[format].mappings.find { |n| n.to == attr }
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
        return unless @mapping_rule.render?(value, @model)

        value = apply_value_map(value)
        value = collapse(value) if @collapsible
        value = denormalize(value)

        @data[@mapping_rule.name] = value
      end

      private

      def transform(value)
        Lutaml::Model::ExportTransformer.call(value, @mapping_rule, @attribute)
      end

      def make_collapsible(value)
        @collapser = CollapsiblesCollapser.new(@attribute.type, collapsible_attributes, @format, value)
        @collapser.collapsibles
      end

      def collapsible_attributes
        @attribute.type.attributes.reject { |_, n| FieldFactory.content_attribute?(n) }
      end

      def serialize(value)
        @attribute.serialize(value, @format, @model.register)
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
        return [] if attr.collection?

        ''
      end

      def collapse(value)
        @collapser.call(value)
      end

      def denormalize(value)
        return value.first if @group_as == 'SINGLETON_OR_ARRAY' && value.one?

        value
      end
    end
  end
end
