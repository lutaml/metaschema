# frozen_string_literal: true

require 'lutaml/model'

require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'

module Metaschema
  class TargetedHasCardinalityConstraintType < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :level, :string, default: -> { 'ERROR' }
    attribute :target, :string
    attribute :min_occurs, :integer
    attribute :max_occurs, :integer
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType

    xml do
      root 'TargetedHasCardinalityConstraintType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'id', to: :id
      map_attribute 'level', to: :level
      map_attribute 'target', to: :target
      map_attribute 'min-occurs', to: :min_occurs
      map_attribute 'max-occurs', to: :max_occurs
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'remarks', to: :remarks
    end
  end
end
