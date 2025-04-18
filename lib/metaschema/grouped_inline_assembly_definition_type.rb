# frozen_string_literal: true

require 'lutaml/model'

require_relative 'assembly_model_type'
require_relative 'define_assembly_constraints_type'
require_relative 'example_type'
require_relative 'flag_reference_type'
require_relative 'inline_flag_definition_type'
require_relative 'markup_line_datatype'
require_relative 'property_type'
require_relative 'remarks_type'
require_relative 'use_name_type'

module Metaschema
  class GroupedInlineAssemblyDefinitionType < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :index, :integer
    attribute :deprecated, :string
    attribute :formal_name, :string
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :use_name, UseNameType
    attribute :discriminator_value, :string
    attribute :flag, FlagReferenceType, collection: true
    attribute :define_flag, InlineFlagDefinitionType, collection: true
    attribute :model, AssemblyModelType
    attribute :constraint, DefineAssemblyConstraintsType
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true

    xml do
      root 'GroupedInlineAssemblyDefinitionType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'name', to: :name
      map_attribute 'index', to: :index
      map_attribute 'deprecated', to: :deprecated
      map_element 'formal-name', to: :formal_name
      map_element 'description', to: :description
      map_element 'prop', to: :prop
      map_element 'use-name', to: :use_name
      map_element 'discriminator-value', to: :discriminator_value
      map_element 'flag', to: :flag
      map_element 'define-flag', to: :define_flag
      map_element 'model', to: :model
      map_element 'constraint', to: :constraint
      map_element 'remarks', to: :remarks
      map_element 'example', to: :example
    end
  end
end
