# frozen_string_literal: true

module Metaschema
  class TargetedHasCardinalityConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :target, :string
    attribute :min_occurs, :integer
    attribute :max_occurs, :integer
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType

    xml do
      element "TargetedHasCardinalityConstraintType"
      namespace ::Metaschema::Namespace

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "target", to: :target
      map_attribute "min-occurs", to: :min_occurs
      map_attribute "max-occurs", to: :max_occurs
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "remarks", to: :remarks
    end
  end
end
