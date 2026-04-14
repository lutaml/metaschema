# frozen_string_literal: true

module Metaschema
  class InlineFlagDefinitionType < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :index, :integer
    attribute :as_type, :string, default: -> { "string" }
    attribute :default, :string
    attribute :required, :string, default: -> { "no" }
    attribute :deprecated, :string
    attribute :formal_name, FormalName
    attribute :description, MarkupLineDatatype
    attribute :prop, PropertyType, collection: true
    attribute :constraint, DefineFlagConstraintsType
    attribute :remarks, RemarksType
    attribute :example, ExampleType, collection: true

    xml do
      element "InlineFlagDefinitionType"
      namespace ::Metaschema::Namespace

      map_attribute "name", to: :name
      map_attribute "index", to: :index
      map_attribute "as-type", to: :as_type
      map_attribute "default", to: :default
      map_attribute "required", to: :required
      map_attribute "deprecated", to: :deprecated
      map_element "formal-name", to: :formal_name
      map_element "description", to: :description
      map_element "prop", to: :prop
      map_element "constraint", to: :constraint
      map_element "remarks", to: :remarks
      map_element "example", to: :example
    end
  end
end
