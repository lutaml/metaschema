# frozen_string_literal: true

module Metaschema
  class ModelGenerator
    module Services
      # Collapses multiple model instances that share the same flag values
      # into a single instance with array-valued content. Implements the
      # Metaschema "collapsible" field semantics.
      #
      # The inverse operation (expanding collapsed items) is performed by
      # FieldDeserializer#separate.
      class CollapsiblesCollapser
        attr_reader :collapsibles

        def initialize(model_class, collapsible_attributes, format, models)
          @model_class = model_class
          @collapsible_attributes = collapsible_attributes
          @format = format
          @uncollapsible_mappings = model_class.mappings[format].mappings
            .reject { |n| collapsible_attributes.key?(n.to) }
          @collapsibles = []
          @groups = {}
          process(models)
        end

        def call(value)
          @groups.map { |_, group| collapse_group(group, value) }
        end

        private

        def process(models)
          models.each_with_index do |model, index|
            collapsible = create_collapsible(model)
            @collapsibles << collapsible
            group_id = group_id_for(collapsible)
            (@groups[group_id] ||= []) << [index, collapsible]
          end
        end

        def create_collapsible(model)
          @model_class.new(attributes_from(model))
        end

        def attributes_from(model)
          model.class.attributes.each_with_object({}) do |(name, attr), attrs|
            value = model.public_send(name)
            next if value == attr.default && @collapsible_attributes.key?(name)

            attrs[name] = value
          end
        end

        def group_id_for(model)
          @collapsible_attributes.transform_values { |attr| model.public_send(attr.name) }
        end

        def collapse_group(group, value)
          indices = group.map { |idx, _| idx }
          first_collapsed = value[indices.first]

          return first_collapsed if indices.one?

          merge_uncollapsible(first_collapsed, indices, value)
        end

        def merge_uncollapsible(first, indices, value)
          return first unless @uncollapsible_mappings.any?

          result = first.dup
          @uncollapsible_mappings.each do |rule|
            values = indices.map { |idx| value[idx][rule.name] }
            result[rule.name] = values
          end
          result
        end
      end
    end
  end
end
