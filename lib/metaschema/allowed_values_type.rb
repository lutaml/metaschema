require "lutaml/model"

require_relative "allowed_value_type"
require_relative "markup_line_datatype"
require_relative "property_type"
require_relative "remarks_type"

module Metaschema
  class AllowedValuesType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :allow_other, :string, default: -> { "no" }
    attribute :extensible, :string, default: -> { "external" }
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :enum, AllowedValueType, collection: true
    attribute :remarks, RemarksType

    xml do
      root "AllowedValuesType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

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
