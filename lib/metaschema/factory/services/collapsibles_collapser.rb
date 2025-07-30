# frozen_string_literal: true

module Metaschema
  module Factory
    class CollapsiblesCollapser
      class Item
        attr_reader :index, :value, :group_id

        def initialize(model, index)
          @index = index
          @value = model
        end
      end

      attr_reader :collapsibles

      def initialize(model, collapsible_attributes, format, models)
        @model = model
        @collapsible_attributes = collapsible_attributes
        @format = format
        @uncollapsible_mappings = @model.mappings[format].mappings.reject { |n| collapsible_attributes.key?(n.to) }
        @collapsibles = []
        @groups = {}
        process(models)
      end

      def call(value)
        @groups.map { |_, n| collapse_group(n, value) }
      end

      private

      def process(models)
        models.each_with_index do |model, index|
          collapsible = create_collapsible(model)
          @collapsibles << collapsible
          (@groups[group_id_for(collapsible)] ||= []) << Item.new(collapsible, index)
        end
      end

      def create_collapsible(model)
        model.class.new(attributes_from(model))
      end

      def attributes_from(model)
        model.class.attributes.each_with_object({}) do |(name, attr), attrs|
          value = model.public_send(name)
          next if value == attr.default && @collapsible_attributes.key?(name)

          attrs[name] = value
        end
      end

      def group_id_for(model)
        @collapsible_attributes.transform_values { |n| model.public_send(n.name) }
      end

      def collapse(value)
        @groups.map { |_, group| collapse_group(group, value) }
      end

      def collapse_group(group, value)
        first, = list = group.map { |n| value[n.index] }
        return first if list.one?

        first.merge(uncollapsed_values_from(list))
      end

      def uncollapsed_values_from(list)
        @uncollapsible_mappings.to_h { |rule| [rule.name, list.map { |n| n[rule.name] }] }
      end
    end
  end
end
