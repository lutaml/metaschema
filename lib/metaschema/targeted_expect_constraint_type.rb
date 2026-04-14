# frozen_string_literal: true

module Metaschema
  class TargetedExpectConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :test, :string
    attribute :target, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :message, :string
    attribute :remarks, RemarksType

    xml do
      element "TargetedExpectConstraintType"
      namespace ::Metaschema::Namespace

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "test", to: :test
      map_attribute "target", to: :target
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "message", to: :message
      map_element "remarks", to: :remarks
    end
  end
end
