require "lutaml/model"

require_relative "assembly_reference_type"
require_relative "field_reference_type"
require_relative "inline_assembly_definition_type"
require_relative "inline_field_definition_type"

module Metaschema
  class ChoiceType < Lutaml::Model::Serializable
    attribute :assembly, AssemblyReferenceType, collection: true
    attribute :field, FieldReferenceType, collection: true
    attribute :define_assembly, InlineAssemblyDefinitionType, collection: true
    attribute :define_field, InlineFieldDefinitionType, collection: true

    xml do
      root "ChoiceType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_element "field", to: :field
      map_element "define-assembly", to: :define_assembly
      map_element "assembly", to: :assembly
      map_element "define-field", to: :define_field
    end
  end
end
