require "lutaml/model"

require_relative "any_type"
require_relative "assembly_reference_type"
require_relative "choice_type"
require_relative "field_reference_type"
require_relative "grouped_choice_type"
require_relative "inline_assembly_definition_type"
require_relative "inline_field_definition_type"

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
      root "AssemblyModelType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

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
