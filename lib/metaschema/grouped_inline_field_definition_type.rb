# frozen_string_literal: true

module Metaschema
  class GroupedInlineFieldDefinitionType < Lutaml::Model::Serializable
    attribute :as_type, :string, default: -> { "string" }
    attribute :collapsible, :string, default: -> { "no" }
    attribute :name, :string
    attribute :index, :integer
    attribute :in_xml, :string, default: -> { "WRAPPED" }
    attribute :deprecated, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :discriminator_value, :string
    attribute :json_value_key, JsonValueKey

    attribute :json_value_key_flag, JsonValueKeyFlagType
    attribute :flag, FlagReferenceType, collection: true
    attribute :define_flag, InlineFlagDefinitionType, collection: true
    attribute :constraint, DefineFieldConstraintsType
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true

    xml do
      element "GroupedInlineFieldDefinitionType"
      namespace ::Metaschema::Namespace

      map_attribute "as-type", to: :as_type
      map_attribute "collapsible", to: :collapsible
      map_attribute "name", to: :name
      map_attribute "index", to: :index
      map_attribute "in-xml", to: :in_xml
      map_attribute "deprecated", to: :deprecated
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "use-name", to: :use_name
      map_element "discriminator-value", to: :discriminator_value
      map_element "json-value-key", to: :json_value_key
      map_element "json-value-key-flag", to: :json_value_key_flag
      map_element "flag", to: :flag
      map_element "define-flag", to: :define_flag
      map_element "constraint", to: :constraint
      map_element "remarks", to: :remarks
      map_element "example", to: :example
    end
  end
end
