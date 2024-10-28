# frozen_string_literal: true

require 'lutaml/model'

require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'

module Metaschema
  class TargetedMatchesConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { 'ERROR' }
    attribute :regex, :string
    attribute :datatype, :string
    attribute :target, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType

    xml do
      root 'TargetedMatchesConstraintType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'id', to: :id
      map_attribute 'level', to: :level
      map_attribute 'regex', to: :regex
      map_attribute 'datatype', to: :datatype
      map_attribute 'target', to: :target
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'remarks', to: :remarks
    end
  end
end
