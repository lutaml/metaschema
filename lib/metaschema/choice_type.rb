# frozen_string_literal: true

module Metaschema
  class ChoiceType < Lutaml::Model::Serializable
    attribute :assembly, AssemblyReferenceType, collection: true
    attribute :field, FieldReferenceType, collection: true
    attribute :define_assembly, InlineAssemblyDefinitionType, collection: true
    attribute :define_field, InlineFieldDefinitionType, collection: true

    xml do
      element "ChoiceType"
      namespace ::Metaschema::Namespace

      map_element "field", to: :field
      map_element "define-assembly", to: :define_assembly
      map_element "assembly", to: :assembly
      map_element "define-field", to: :define_field
    end
  end
end
