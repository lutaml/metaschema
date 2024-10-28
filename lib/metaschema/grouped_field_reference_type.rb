# frozen_string_literal: true

require 'lutaml/model'

require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'
require_relative 'use_name_type'

module Metaschema
  class GroupedFieldReferenceType < Lutaml::Model::Serializable
    attribute :ref, :string
    attribute :deprecated, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :discriminator_value, :string
    attribute :remarks, RemarksType

    xml do
      root 'GroupedFieldReferenceType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'ref', to: :ref
      map_attribute 'deprecated', to: :deprecated
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'use-name', to: :use_name
      map_element 'discriminator-value', to: :discriminator_value
      map_element 'remarks', to: :remarks
    end
  end
end
