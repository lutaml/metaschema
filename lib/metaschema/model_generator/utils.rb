# frozen_string_literal: true

module Metaschema
  class ModelGenerator
    # Shared utility methods extracted from ModelGenerator.
    # Used by FieldFactory, AssemblyFactory, and ModelGenerator itself.
    module Utils
      RESERVED_WORDS = %i[class module method hash object_id nil? is_a? kind_of?
                          instance_of? respond_to? send].freeze

      # Convert a Metaschema name (hyphenated) to a safe Ruby attribute name.
      def self.safe_attr(name)
        sym = name.gsub("-", "_").to_sym
        RESERVED_WORDS.include?(sym) ? :"#{sym}_attr" : sym
      end

      # Check if a max-occurs value represents an unbounded collection.
      def self.unbounded?(max_occurs)
        max_occurs.nil? || max_occurs == "unbounded" ||
          (max_occurs.respond_to?(:to_i) && max_occurs.to_i > 1)
      end

      # Generate a scoped name for inline field classes to avoid collisions.
      def self.scoped_field_name(field_name, parent_name = nil)
        if parent_name
          "Field_#{parent_name}_#{field_name.gsub('-', '_')}"
        else
          "Field_#{field_name.gsub('-', '_')}"
        end
      end

      # Create an anonymous class with a debuggable temporary name.
      def self.create_model(name, super_class = Lutaml::Model::Serializable)
        model = Class.new(super_class)
        set_model_temporary_name(model, name)
        model
      end

      # Check if an object is a lutaml-model Serializable subclass.
      def self.model?(object)
        object.is_a?(Class) && object.include?(Lutaml::Model::Serialize)
      end

      # Assign a human-readable name to an anonymous class for debugging.
      def self.set_model_temporary_name(model, name)
        display_name = name.gsub(/(?:^|[-._]+)./) do |n|
          n[-1].upcase
        end + ":Class"

        if model.respond_to?(:set_temporary_name)
          model.set_temporary_name(display_name)
          return
        end

        model.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def self.to_s
            name || #{display_name.inspect}
          end
          singleton_class.alias_method :inspect, :to_s
        RUBY
      end
    end
  end
end
