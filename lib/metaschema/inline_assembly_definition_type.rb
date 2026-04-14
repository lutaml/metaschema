# frozen_string_literal: true

module Metaschema
  class AssemblyModelType < Lutaml::Model::Serializable; end

  class InlineAssemblyDefinitionType < Lutaml::Model::Serializable
    attribute :min_occurs, :integer, default: -> { "0" }
    attribute :max_occurs, :string, default: -> { "1" }
    attribute :name, :string
    attribute :index, :integer
    attribute :deprecated, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :json_key, JsonKeyType
    attribute :json_value_key, JsonValueKey

    attribute :json_value_key_flag, JsonValueKeyFlagType
    attribute :group_as, GroupAsType
    attribute :flag, FlagReferenceType, collection: true
    attribute :define_flag, InlineFlagDefinitionType, collection: true
    attribute :model, AssemblyModelType
    attribute :constraint, DefineAssemblyConstraintsType
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true

    xml do
      element "InlineAssemblyDefinitionType"
      namespace ::Metaschema::Namespace

      map_attribute "min-occurs", to: :min_occurs
      map_attribute "max-occurs", to: :max_occurs
      map_attribute "name", to: :name
      map_attribute "index", to: :index
      map_attribute "deprecated", to: :deprecated
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "json-key", to: :json_key
      map_element "json-value-key", to: :json_value_key
      map_element "json-value-key-flag", to: :json_value_key_flag
      map_element "group-as", to: :group_as
      map_element "flag", to: :flag
      map_element "define-flag", to: :define_flag
      map_element "model", to: :model
      map_element "constraint", to: :constraint
      map_element "remarks", to: :remarks
      map_element "example", to: :example
    end
  end
end
