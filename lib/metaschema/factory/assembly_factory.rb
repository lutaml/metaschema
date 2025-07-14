# frozen_string_literal: true

require 'lutaml/model'

require_relative '../refinements/object_try'
require_relative 'field_factory'
require_relative 'utils'

module Metaschema
  module Factory
    class AssemblyFactory # rubocop:disable Metrics/ClassLength
      using Refinements::ObjectTry

      def initialize(spec, root, model = Utils.create_model(spec.name))
        @spec = spec
        @root = root
        @model = model
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
        define_attributes_for :flag
        define_attributes_for :define_flag
        define_attributes_for :model
      end

      def define_attributes_for(name, spec = @spec, *args)
        value = spec.public_send(name)
        return if value.nil?

        send :"define_attributes_for_#{name}", value, *args
      end

      %i[
        flag
        define_flag
        choice
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

      def define_attributes_for_model(spec)
        define_attributes_for :field, spec
        define_attributes_for :define_field, spec
        define_attributes_for :assembly, spec
        define_attributes_for :define_assembly, spec
        define_attributes_for :choice, spec
      end

      %i[
        field
        define_field
        assembly
        define_assembly
      ].each do |name|
        private(define_method(:"define_attributes_for_#{name}") do |items, model_or_choice = @model|
          items.each do |item|
            send :"define_attributes_for_#{name}_item", item, model_or_choice
          end
        end)
      end

      def define_attributes_for_field_item(ref, model_or_choice)
        name = @root.attribute_name_for(ref)

        if ref.group_as&.then { |n| n.in_json == 'BY_KEY' || n.in_xml == 'GROUPED' }
          type = @root.create_collection(ref)
          model_or_choice.attribute name, type
        else
          type = @root.type_for(ref)
          opts = { collection: attribute_collection_for(ref) }.compact
          model_or_choice.attribute name, type, opts
        end
      end

      def attribute_collection_for(type)
        max = type.max_occurs
        return if max == '1'

        min = type.min_occurs
        max = max == 'unbounded' ? nil : max.to_i
        min.zero? && max.nil? ? true : min..max
      end

      def define_attributes_for_define_field_item(spec, model_or_choice)
        name = @root.attribute_name_for(spec)
        type = Utils.complex_field?(spec) ? FieldFactory.new(spec, @root).call : Utils.attribute_type_for(spec.as_type)
        opts = { collection: attribute_collection_for(spec) }.compact
        model_or_choice.attribute name, type, opts
      end

      def define_attributes_for_assembly_item(ref, model_or_choice)
        name = @root.attribute_name_for(ref)

        if ref.group_as&.in_xml == 'GROUPED'
          type = @root.create_collection(ref)
          model_or_choice.attribute name, type
        else
          type = @root.type_for(ref)
          opts = { collection: attribute_collection_for(ref) }.compact
          model_or_choice.attribute name, type, opts
        end
      end

      def define_attributes_for_define_assembly_item(spec, model_or_choice)
        name = @root.attribute_name_for(spec)
        type = self.class.new(spec, @root).call
        opts = { collection: attribute_collection_for(spec) }.compact
        model_or_choice.attribute name, type, opts
      end

      def define_attributes_for_choice_item(spec)
        factory = self
        @model.choice do |choice|
          factory.instance_eval do
            define_attributes_for :field, spec, choice
            define_attributes_for :define_field, spec, choice
            define_attributes_for :assembly, spec, choice
            define_attributes_for :define_assembly, spec, choice
          end
        end
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

        define_json_mappings_for :flag
        define_json_mappings_for :define_flag
        define_json_mappings_for :model
      end

      def define_json_root
        if @spec.try(:root_name)
          json_mapping.root root_name
        else
          json_mapping.no_root
        end
      end

      def root_name
        @spec.try(:root_name)&.content || @root.effective_name_for(@spec)
      end

      def json_mapping
        @model.mappings.fetch(:json)
      end

      def define_json_mappings_for(name, spec = @spec)
        value = spec.public_send(name)
        return if value.nil?

        send :"define_json_mappings_for_#{name}", value
      end

      %i[
        flag
        define_flag
        field
        define_field
        assembly
        define_assembly
        choice
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

      def define_json_mappings_for_model(spec)
        define_json_mappings_for :field, spec
        define_json_mappings_for :define_field, spec
        define_json_mappings_for :assembly, spec
        define_json_mappings_for :define_assembly, spec
        define_json_mappings_for :choice, spec
      end

      def define_json_mappings_for_field_item(ref)
        name = @root.mapping_name_in_json_for(ref)
        attr = @root.attribute_name_for(ref)
        json_mapping.map name, to: attr
      end

      def define_json_mappings_for_define_field_item(spec)
        name = @root.mapping_name_in_json_for(spec)
        attr = @root.attribute_name_for(spec)
        json_mapping.map name, to: attr
      end

      def define_json_mappings_for_assembly_item(ref)
        name = @root.mapping_name_in_json_for(ref)
        attr = @root.attribute_name_for(ref)
        json_mapping.map name, to: attr
      end

      def define_json_mappings_for_define_assembly_item(spec)
        name = @root.mapping_name_in_json_for(spec)
        attr = @root.attribute_name_for(spec)
        json_mapping.map name, to: attr, render_empty: :as_empty
      end

      def define_json_mappings_for_choice_item(spec)
        define_json_mappings_for :field, spec
        define_json_mappings_for :define_field, spec
        define_json_mappings_for :assembly, spec
        define_json_mappings_for :define_assembly, spec
      end

      # === XML

      def define_xml_mapping
        define_xml_root
        define_xml_namespace

        define_xml_mappings_for :flag
        define_xml_mappings_for :define_flag
        define_xml_mappings_for :model
      end

      def define_xml_root
        xml_mapping.root root_name, ordered: true
      end

      def xml_mapping
        @model.mappings.fetch(:xml)
      end

      def define_xml_namespace
        xml_mapping.namespace @root.schema.namespace
      end

      def define_xml_mappings_for(name, spec = @spec)
        value = spec.public_send(name)
        return if value.nil?

        send :"define_xml_mappings_for_#{name}", value
      end

      %i[
        flag
        define_flag
        field
        define_field
        assembly
        define_assembly
        choice
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
        name = spec.name
        attr = @root.attribute_name_for(spec)
        xml_mapping.map_attribute name, to: attr
      end

      def define_xml_mappings_for_model(spec)
        define_xml_mappings_for :field, spec
        define_xml_mappings_for :define_field, spec
        define_xml_mappings_for :assembly, spec
        define_xml_mappings_for :define_assembly, spec
        define_xml_mappings_for :choice, spec
      end

      def define_xml_mappings_for_field_item(ref) # rubocop:disable Metrics/MethodLength
        attr = @root.attribute_name_for(ref)

        if ref.in_xml == 'UNWRAPPED'
          type = Utils.attribute_type_for(@root.spec_for(ref).as_type)

          if Utils.model?(type)
            delegate_model_xml_mappings(type, attr)
          else
            xml_mapping.map_content to: attr
          end
        else
          name = @root.mapping_name_in_xml_for(ref)
          xml_mapping.map_element name, to: attr
        end
      end

      def delegate_model_xml_mappings(model, attr)
        mapping = model.mappings[:xml]
        return if mapping.nil?

        delegate_xml_attribute_mappings(mapping, attr)
        delegate_xml_content_mapping(mapping, attr)
        delegate_xml_element_mappings(mapping, attr)
        delegate_xml_raw_mapping(mapping, attr)
      end

      def delegate_xml_attribute_mappings(mapping, attr)
        mapping.attributes.each do |rule|
          xml_mapping.map_attribute rule.name, to: rule.to, delegate: attr
        end
      end

      def delegate_xml_content_mapping(mapping, attr)
        rule = mapping.content_mapping
        return if rule.nil?

        xml_mapping.map_content to: rule.to, delegate: attr
      end

      def delegate_xml_element_mappings(mapping, attr)
        mapping.elements.each do |rule|
          xml_mapping.map_element rule.name, to: rule.to, delegate: attr
        end
      end

      def delegate_xml_raw_mapping(mapping, attr)
        rule = mapping.raw_mapping
        return if rule.nil?

        xml_mapping.map_all to: rule.to, delegate: attr
      end

      def define_xml_mappings_for_define_field_item(spec)
        name = @root.mapping_name_in_xml_for(spec)
        attr = @root.attribute_name_for(spec)
        xml_mapping.map_element name, to: attr
      end

      def define_xml_mappings_for_assembly_item(ref)
        name = @root.mapping_name_in_xml_for(ref)
        attr = @root.attribute_name_for(ref)
        xml_mapping.map_element name, to: attr
      end

      def define_xml_mappings_for_define_assembly_item(spec)
        name = @root.mapping_name_in_xml_for(spec)
        attr = @root.attribute_name_for(spec)
        xml_mapping.map_element name, to: attr
      end

      def define_xml_mappings_for_choice_item(spec)
        define_xml_mappings_for :field, spec
        define_xml_mappings_for :define_field, spec
        define_xml_mappings_for :assembly, spec
        define_xml_mappings_for :define_assembly, spec
      end
    end
  end
end
