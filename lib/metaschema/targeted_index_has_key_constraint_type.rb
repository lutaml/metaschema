# frozen_string_literal: true

module Metaschema
  class TargetedIndexHasKeyConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :name, :string
    attribute :target, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :key_field, KeyField, collection: true
    attribute :remarks, RemarksType

    xml do
      element "TargetedIndexHasKeyConstraintType"
      namespace ::Metaschema::Namespace

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "name", to: :name
      map_attribute "target", to: :target
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "key-field", to: :key_field
      map_element "remarks", to: :remarks
    end
  end
end
