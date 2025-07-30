# frozen_string_literal: true

require 'lutaml/model'

require_relative '../constants'
require_relative 'concerns/as_markup_line'
require_relative 'concerns/as_markup_multiline'

module Metaschema
  module Factory
    module Utils
      def self.attribute_type_for(data_type)
        Constants::ATTRIBUTE_TYPE_BY_DATA_TYPE.fetch(data_type)
      end

      def self.complex_field?(field)
        field.flag&.any? ||
          field.define_flag&.any? ||
          model?(attribute_type_for(field.as_type))
      end

      def self.create_model(name, super_class = Lutaml::Model::Serializable, &block)
        model = Class.new(super_class)
        set_model_temporary_name(model, name)
        model.class_eval(&block) if block_given?
        model
      end

      def self.initial_type_for_field(field)
        if complex_field?(field)
          type = create_model(field.name)
          type.include(AsMarkupLine) if field.as_type == 'markup-line'
          type.include(AsMarkupMultiline) if field.as_type == 'markup-multiline'
          type
        else
          attribute_type_for(field.as_type)
        end
      end

      def self.model?(object)
        object.is_a?(Class) && object.include?(Lutaml::Model::Serialize)
      end

      def self.normalize_attribute_name(name)
        name = name.tr('-.', '_')
        return :"#{name}_" if Constants::RESERVED_ATTRIBUTE_NAMES.include?(name)

        name.to_sym
      end

      def self.set_model_temporary_name(model, name) # rubocop:disable Metrics/MethodLength
        name = "#{name.gsub(/(?:^|[-._]+)./) { |n| n[-1].upcase }}:Class"

        if model.respond_to?(:set_temporary_name)
          model.set_temporary_name(name)
          return
        end

        model.class_eval <<~RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          def self.to_s
            name || #{name.inspect}
          end
          singleton_class.alias_method :inspect, :to_s

          def inspect
            return super if self.class.name

            super.sub(self.class.method(:inspect).super_method.call, self.class.to_s)
          end
        RUBY
      end
    end
  end
end
