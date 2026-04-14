# frozen_string_literal: true

module Metaschema
  class GroupedFieldReferenceType < Lutaml::Model::Serializable
    attribute :ref, :string
    attribute :deprecated, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :discriminator_value, :string
    attribute :remarks, RemarksType

    xml do
      element "GroupedFieldReferenceType"
      namespace ::Metaschema::Namespace

      map_attribute "ref", to: :ref
      map_attribute "deprecated", to: :deprecated
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "use-name", to: :use_name
      map_element "discriminator-value", to: :discriminator_value
      map_element "remarks", to: :remarks
    end
  end
end
