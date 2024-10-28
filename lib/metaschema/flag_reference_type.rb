# frozen_string_literal: true

require 'lutaml/model'

require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'
require_relative 'use_name_type'

module Metaschema
  class FlagReferenceType < Lutaml::Model::Serializable
    attribute :ref, :string
    attribute :index, :integer
    attribute :required, :string, default: -> { 'no' }
    attribute :default, :string
    attribute :deprecated, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :remarks, RemarksType

    xml do
      root 'FlagReferenceType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'ref', to: :ref
      map_attribute 'index', to: :index
      map_attribute 'required', to: :required
      map_attribute 'default', to: :default
      map_attribute 'deprecated', to: :deprecated
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'use-name', to: :use_name
      map_element 'remarks', to: :remarks
    end
  end
end
