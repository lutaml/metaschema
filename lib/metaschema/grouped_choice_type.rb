require "lutaml/model"

require_relative "group_as_type"
require_relative "grouped_assembly_reference_type"
require_relative "grouped_field_reference_type"
require_relative "grouped_inline_assembly_definition_type"
require_relative "grouped_inline_field_definition_type"
require_relative "json_key_type"

module Metaschema
  class GroupedChoiceType < Lutaml::Model::Serializable
    attribute :min_occurs, :integer, default: -> { "0" }
    attribute :max_occurs, :string, default: -> { "unbounded" }
    attribute :json_key, JsonKeyType
    attribute :group_as, GroupAsType
    attribute :discriminator, :string, default: -> { "object-type" }
    attribute :assembly, GroupedAssemblyReferenceType, collection: true
    attribute :field, GroupedFieldReferenceType, collection: true
    attribute :define_assembly, GroupedInlineAssemblyDefinitionType, collection: true
    attribute :define_field, GroupedInlineFieldDefinitionType, collection: true

    xml do
      root "GroupedChoiceType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0", "xmlns"

      map_attribute "min-occurs", to: :min_occurs
      map_attribute "max-occurs", to: :max_occurs
      map_element "json-key", to: :json_key
      map_element "group-as", to: :group_as
      map_element "discriminator", to: :discriminator
      map_element "assembly", to: :assembly
      map_element "field", to: :field
      map_element "define-assembly", to: :define_assembly
      map_element "define-field", to: :define_field
    end
  end
end
