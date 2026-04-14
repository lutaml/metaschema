# frozen_string_literal: true

module Metaschema
  class TargetedMatchesConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :regex, :string
    attribute :datatype, :string
    attribute :target, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType

    xml do
      element "TargetedMatchesConstraintType"
      namespace ::Metaschema::Namespace

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "regex", to: :regex
      map_attribute "datatype", to: :datatype
      map_attribute "target", to: :target
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "remarks", to: :remarks
    end
  end
end
