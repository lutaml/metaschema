# frozen_string_literal: true

module Metaschema
  class AssemblyModelType < Lutaml::Model::Serializable
    attribute :assembly, AssemblyReferenceType, collection: true
    attribute :field, FieldReferenceType, collection: true
    attribute :define_assembly, InlineAssemblyDefinitionType, collection: true
    attribute :define_field, InlineFieldDefinitionType, collection: true
    attribute :choice, ChoiceType, collection: true
    attribute :choice_group, GroupedChoiceType, collection: true
    attribute :any, AnyType

    xml do
      element "AssemblyModelType"
      ordered
      namespace ::Metaschema::Namespace

      map_element "field", to: :field
      map_element "define-assembly", to: :define_assembly
      map_element "assembly", to: :assembly
      map_element "define-field", to: :define_field
      map_element "choice", to: :choice
      map_element "choice-group", to: :choice_group
      map_element "any", to: :any
    end
  end
end
