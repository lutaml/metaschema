# frozen_string_literal: true

require 'lutaml/model'

require_relative 'define_field_constraints_type'
require_relative 'example_type'
require_relative 'flag_reference_type'
require_relative 'inline_flag_definition_type'
require_relative 'json_value_key_flag_type'
require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'
require_relative 'use_name_type'

module Metaschema
  class GroupedInlineFieldDefinitionType < Lutaml::Model::Serializable
    attribute :as_type, :string, default: -> { 'string' }
    attribute :collapsible, :string, default: -> { 'no' }
    attribute :name, :string
    attribute :index, :integer
    attribute :in_xml, :string, default: -> { 'WRAPPED' }
    attribute :deprecated, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :discriminator_value, :string
    attribute :json_value_key, :string
    attribute :json_value_key_flag, JsonValueKeyFlagType
    attribute :flag, FlagReferenceType, collection: true
    attribute :define_flag, InlineFlagDefinitionType, collection: true
    attribute :constraint, DefineFieldConstraintsType
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true

    xml do
      root 'GroupedInlineFieldDefinitionType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'as-type', to: :as_type
      map_attribute 'collapsible', to: :collapsible
      map_attribute 'name', to: :name
      map_attribute 'index', to: :index
      map_attribute 'in-xml', to: :in_xml
      map_attribute 'deprecated', to: :deprecated
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'use-name', to: :use_name
      map_element 'discriminator-value', to: :discriminator_value
      map_element 'json-value-key', to: :json_value_key
      map_element 'json-value-key-flag', to: :json_value_key_flag
      map_element 'flag', to: :flag
      map_element 'define-flag', to: :define_flag
      map_element 'constraint', to: :constraint
      map_element 'remarks', to: :remarks
      map_element 'example', to: :example
    end
  end
end
