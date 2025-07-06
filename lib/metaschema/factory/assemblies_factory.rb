# frozen_string_literal: true

require 'lutaml/model'

require_relative '../assembly_reference_type'
require_relative '../field_reference_type'
require_relative '../flag_reference_type'
require_relative '../global_assembly_definition_type'
require_relative '../global_field_definition_type'
require_relative '../global_flag_definition_type'
require_relative '../inline_assembly_definition_type'
require_relative '../inline_field_definition_type'
require_relative '../inline_flag_definition_type'
require_relative '../refinements/object_try'
require_relative 'assembly_factory'
require_relative 'field_factory'
require_relative 'utils'

module Metaschema
  module Factory
    class AssembliesFactory
      using Refinements::ObjectTry

      COLLECTION_INSTANCES_ATTRIBUTE_NAME = :items

      attr_reader :schema

      def initialize(schema)
        @schema = schema
      end

      def pretty_print_instance_variables
        (instance_variables - %i[@assembly_map @field_map @flag_map @schema]).sort
      end

      def call
        set_global_mappings
        process_global_mappings
        assemblies
      end

      def assemblies
        @assembly_map.each_value.map(&:first)
      end

      def attribute_name_for(element)
        name = element.try(:group_as)&.name || effective_name_for(element)
        Utils.normalize_attribute_name(name)
      end

      def effective_name_for(element)
        element.try(:use_name)&.content ||
          (element.respond_to?(:ref) ? effective_name_for(spec_for(element)) : element.name)
      end

      def mapping_name_in_json_for(element)
        element.try(:group_as)&.name || effective_name_for(element)
      end

      def mapping_name_in_xml_for(element)
        element.try(:group_as)&.then { |n| n.name if n.in_xml == 'GROUPED' } ||
          effective_name_for(element)
      end

      def spec_for(ref)
        type_spec_for(ref).fetch(1)
      end

      def type_for(element)
        type_spec_for(element).fetch(0)
      end

      def type_spec_for(element)
        case element
        when AssemblyReferenceType then @assembly_map.fetch(element.ref)
        when FieldReferenceType then @field_map.fetch(element.ref)
        when FlagReferenceType then @flag_map.fetch(element.ref)
        when GlobalAssemblyDefinitionType then @assembly_map.fetch(element.name)
        when GlobalFieldDefinitionType then @field_map.fetch(element.name)
        when GlobalFlagDefinitionType then @flag_map.fetch(element.name)
        else
          raise ArgumentError, "Unknown element: #{element}"
        end
      end

      def create_collection(ref) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        factory = self
        type, spec = type_spec_for(ref)
        name = ref.group_as.name
        attr = COLLECTION_INSTANCES_ATTRIBUTE_NAME
        Utils.create_model(name, Lutaml::Model::Collection) do
          instances attr, type

          json do
            root name

            if ref.group_as.in_json == 'BY_KEY'
              map_key to_instance: Utils.normalize_attribute_name(spec.json_key.flag_ref)
              map_value as_attribute: FieldFactory::CONTENT_ATTRIBUTE_NAME
              map_instances to: attr
            else
              map factory.effective_name_for(spec), to: attr
            end
          end

          xml do
            root name
            namespace factory.schema.namespace

            map_element factory.effective_name_for(spec), to: attr
          end
        end
      end

      private

      def set_global_mappings
        @flag_map = @schema.define_flag.to_h { |n| [n.name, [Utils.attribute_type_for(n.as_type), n]] }
        @field_map = @schema.define_field.to_h { |n| [n.name, [Utils.create_model(n.name), n]] }
        @assembly_map = @schema.define_assembly.to_h { |n| [n.name, [Utils.create_model(n.name), n]] }
      end

      def process_global_mappings
        @field_map.each_value { |type, spec| FieldFactory.new(spec, self, type).call }
        @assembly_map.each_value { |type, spec| AssemblyFactory.new(spec, self, type).call }
      end
    end
  end
end
