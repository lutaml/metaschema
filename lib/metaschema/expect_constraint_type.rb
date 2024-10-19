require "lutaml/model"

require_relative "markup_line_datatype"
require_relative "property_type"
require_relative "remarks_type"

module Metaschema
  class ExpectConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { "ERROR" }
    attribute :test, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :message, :string
    attribute :remarks, RemarksType

    xml do
      root "ExpectConstraintType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0", "xmlns"

      map_attribute "id", to: :id
      map_attribute "level", to: :level
      map_attribute "test", to: :test
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "message", to: :message
      map_element "remarks", to: :remarks
    end
  end
end
