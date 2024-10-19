require "lutaml/model"

require_relative "group_as_type"
require_relative "markup_line_datatype"
require_relative "property_type"
require_relative "remarks_type"
require_relative "use_name_type"

module Metaschema
  class FieldReferenceType < Lutaml::Model::Serializable
    attribute :ref, :string
    attribute :index, :integer
    attribute :min_occurs, :integer, default: -> { "0" }
    attribute :max_occurs, :string, default: -> { "1" }
    attribute :in_xml, :string, default: -> { "WRAPPED" }
    attribute :default, :string
    attribute :deprecated, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :group_as, GroupAsType
    attribute :remarks, RemarksType

    xml do
      root "FieldReferenceType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "ref", to: :ref
      map_attribute "index", to: :index
      map_attribute "min-occurs", to: :min_occurs
      map_attribute "max-occurs", to: :max_occurs
      map_attribute "in-xml", to: :in_xml
      map_attribute "default", to: :default
      map_attribute "deprecated", to: :deprecated
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "use-name", to: :use_name
      map_element "group-as", to: :group_as
      map_element "remarks", to: :remarks
    end
  end
end
