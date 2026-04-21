# frozen_string_literal: true

module Metaschema
  # Represents an <augment> element in a metaschema document.
  # Augments add documentation, flags, or properties to definitions
  # from imported modules without modifying the original module.
  #
  # Example:
  #   <augment name="metadata">
  #     <formal-name>Document Metadata</formal-name>
  #     <description>Provides information about the document.</description>
  #     <flag ref="document-id" />
  #   </augment>
  class AugmentType < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true
    attribute :flag, FlagReferenceType, collection: true
    attribute :define_flag, InlineFlagDefinitionType, collection: true

    xml do
      element "augment"
      ordered
      namespace ::Metaschema::Namespace

      map_attribute "name", to: :name
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "remarks", to: :remarks
      map_element "example", to: :example
      map_element "flag", to: :flag
      map_element "define-flag", to: :define_flag
    end
  end
end
