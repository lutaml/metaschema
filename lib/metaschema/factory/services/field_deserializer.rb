# frozen_string_literal: true

require 'lutaml/model'

module Metaschema
  module Factory
    class FieldDeserializer
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
        data = normalize(@data)
        data = separate(data) if @collapsible
        data = cast(data)
        validate_collection!(data)
        data = transform(data)

        @model.public_send(:"#{@attribute.name}=", data)
      end

      private

      def normalize(data)
        return [data].compact if @group_as == 'SINGLETON_OR_ARRAY' && !data.is_a?(Array)

        data
      end

      def separate(data)
        data.each_with_object([]) do |item, results|
          size = item.each_value.find { |n| n.is_a?(Array) }&.size

          if size
            size.times do |index|
              results << item.transform_values { |n| n.is_a?(Array) ? n[index] : n }
            end
          else
            results << item
          end
        end
      end

      def cast(data)
        opts = { polymorphic: @mapping_rule&.polymorphic }.compact
        @attribute.cast(data, @format, @model.register, opts)
      end

      def validate_collection!(data)
        @attribute.valid_collection!(data, @model.class)
      end

      def transform(data)
        Lutaml::Model::ImportTransformer.call(data, @mapping_rule, @attribute)
      end
    end
  end
end
