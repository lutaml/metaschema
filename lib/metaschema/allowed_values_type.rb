# frozen_string_literal: true

module Metaschema
  class AllowedValuesType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :allow_other, :string, default: -> { "no" }
    attribute :extensible, :string, default: -> { "external" }
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :enum, AllowedValueType, collection: true
    attribute :remarks, RemarksType

    xml do
      element "AllowedValuesType"
      namespace ::Metaschema::Namespace

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "allow-other", to: :allow_other
      map_attribute "extensible", to: :extensible
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "enum", to: :enum
      map_element "remarks", to: :remarks
    end
  end
end
