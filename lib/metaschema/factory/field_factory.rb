# frozen_string_literal: true

require 'lutaml/model'

require_relative '../refinements/object_try'
require_relative 'utils'

module Metaschema
  module Factory
    class FieldFactory # rubocop:disable Metrics/ClassLength
      using Refinements::ObjectTry

      CONTENT_ATTRIBUTE_NAME = :content

      def initialize(spec, root, model = Utils.create_model(spec.name))
        @spec = spec
        @root = root
        @model = model
      end

      def self.content_attribute?(attribute)
        attribute.name == CONTENT_ATTRIBUTE_NAME && attribute.type < Lutaml::Model::Type::Value
      end

      def pretty_print_instance_variables
        (instance_variables - %i[@spec]).sort
      end

      def call
        define_attributes
        define_mappings
        @model
      end

      private

      def define_attributes
        define_attributes_for_markup_data_type
        define_attributes_for :flag
        define_attributes_for :define_flag
        define_attributes_for_simple_data_type
      end

      def define_attributes_for(name, spec = @spec, *args)
        value = spec.public_send(name)
        return if value.nil?

        send :"define_attributes_for_#{name}", value, *args
      end

      def define_attributes_for_markup_data_type
        return unless markup_data_type?

        type = Utils.attribute_type_for(@spec.as_type)
        @model.import_model_attributes(type)
      end

      def markup_data_type?
        %w[markup-line markup-multiline].include?(@spec.as_type)
      end

      def define_attributes_for_simple_data_type
        return unless simple_data_type?

        type = Utils.attribute_type_for(@spec.as_type)
        name = CONTENT_ATTRIBUTE_NAME
        @model.attribute name, type
      end

      def simple_data_type?
        !markup_data_type?
      end

      %i[
        flag
        define_flag
      ].each do |name|
        private(define_method(:"define_attributes_for_#{name}") do |items|
          items.each do |item|
            send :"define_attributes_for_#{name}_item", item
          end
        end)
      end

      def define_attributes_for_flag_item(ref)
        name = @root.attribute_name_for(ref)
        type, spec = @root.type_spec_for(ref)
        opts = { default: spec.default }.compact
        @model.attribute name, type, opts
      end

      def define_attributes_for_define_flag_item(spec)
        name = @root.attribute_name_for(spec)
        type = Utils.attribute_type_for(spec.as_type)
        opts = { default: spec.default }.compact
        @model.attribute name, type, opts
      end

      def define_mappings
        define_mapping :json
        define_mapping :xml
      end

      def define_mapping(format)
        factory = self
        @model.public_send(format) do
          factory.send :"define_#{format}_mapping"
        end
      end

      # === JSON

      def define_json_mapping
        define_json_root

        define_json_mappings_for_markup_data_type
        define_json_mappings_for :flag
        define_json_mappings_for :define_flag
        define_json_mappings_for_simple_data_type
      end

      def define_json_root
        # json_mapping.root root_name
        json_mapping.no_root
      end

      def root_name
        @root.effective_name_for(@spec)
      end

      def json_mapping
        @model.mappings.fetch(:json)
      end

      def define_json_mappings_for(name)
        value = @spec.public_send(name)
        return if value.nil?

        send :"define_json_mappings_for_#{name}", value
      end

      def define_json_mappings_for_markup_data_type
        return unless markup_data_type?

        type = Utils.attribute_type_for(@spec.as_type)
        import_model_json_mappings(type)
      end

      def define_json_mappings_for_simple_data_type
        return unless simple_data_type?

        name = Utils.json_value_key_for_field(@spec)
        attr = CONTENT_ATTRIBUTE_NAME
        json_mapping.map name, to: attr
      end

      def import_model_json_mappings(model)
        mapping = model.mappings[:json]&.deep_dup
        return if mapping.nil?

        json_mapping.mappings += mapping.mappings
      end

      %i[
        flag
        define_flag
      ].each do |name|
        private(define_method(:"define_json_mappings_for_#{name}") do |items|
          items.each do |item|
            send :"define_json_mappings_for_#{name}_item", item
          end
        end)
      end

      def define_json_mappings_for_flag_item(ref)
        name = @root.mapping_name_in_json_for(ref)
        attr = @root.attribute_name_for(ref)
        json_mapping.map name, to: attr
      end

      def define_json_mappings_for_define_flag_item(spec)
        name = @root.mapping_name_in_json_for(spec)
        attr = @root.attribute_name_for(spec)
        json_mapping.map name, to: attr
      end

      # === XML

      def define_xml_mapping
        define_xml_root
        define_xml_namespace

        define_xml_mappings_for_markup_data_type
        define_xml_mappings_for :flag
        define_xml_mappings_for :define_flag
        define_xml_mappings_for_simple_data_type
      end

      def define_xml_root
        xml_mapping.root root_name, mixed: true
      end

      def xml_mapping
        @model.mappings.fetch(:xml)
      end

      def define_xml_namespace
        xml_mapping.namespace @root.schema.namespace
      end

      def define_xml_mappings_for(name)
        value = @spec.public_send(name)
        return if value.nil?

        send :"define_xml_mappings_for_#{name}", value
      end

      def define_xml_mappings_for_markup_data_type
        return unless markup_data_type?

        type = Utils.attribute_type_for(@spec.as_type)
        import_model_xml_mappings(type)
      end

      def define_xml_mappings_for_simple_data_type
        return unless simple_data_type?

        attr = CONTENT_ATTRIBUTE_NAME
        xml_mapping.map_content to: attr
      end

      def import_model_xml_mappings(model)
        mapping = model.mappings[:xml]&.deep_dup
        return if mapping.nil?

        xml_mapping.merge_mapping_attributes(mapping)
        import_xml_content_mapping(mapping)
        xml_mapping.merge_mapping_elements(mapping)
        xml_mapping.merge_elements_sequence(mapping)
        import_xml_raw_mapping(mapping)
      end

      def import_xml_content_mapping(mapping)
        rule = mapping.content_mapping
        return if rule.nil?

        xml_mapping.instance_variable_set :@content_mapping, rule
      end

      def import_xml_raw_mapping(mapping)
        rule = mapping.raw_mapping
        return if rule.nil?

        xml_mapping.instance_variable_set :@raw_mapping, rule
      end

      %i[
        flag
        define_flag
      ].each do |name|
        private(define_method(:"define_xml_mappings_for_#{name}") do |items|
          items.each do |item|
            send :"define_xml_mappings_for_#{name}_item", item
          end
        end)
      end

      def define_xml_mappings_for_flag_item(ref)
        name = @root.mapping_name_in_xml_for(ref)
        attr = @root.attribute_name_for(ref)
        xml_mapping.map_attribute name, to: attr
      end

      def define_xml_mappings_for_define_flag_item(spec)
        name = @root.mapping_name_in_xml_for(spec)
        attr = @root.attribute_name_for(spec)
        xml_mapping.map_attribute name, to: attr
      end
    end
  end
end
