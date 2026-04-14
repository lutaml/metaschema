# frozen_string_literal: true

module Metaschema
  class PropertyType < Lutaml::Model::Serializable
    attribute :namespace, :string, default: -> { "http://csrc.nist.gov/ns/oscal/metaschema/1.0" }
    attribute :name, :string
    attribute :value, :string

    xml do
      element "PropertyType"
      namespace ::Metaschema::Namespace

      map_attribute "namespace", to: :namespace
      map_attribute "name", to: :name
      map_attribute "value", to: :value
    end
  end
end
