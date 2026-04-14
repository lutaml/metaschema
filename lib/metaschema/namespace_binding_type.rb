# frozen_string_literal: true

module Metaschema
  class NamespaceBindingType < Lutaml::Model::Serializable
    attribute :prefix, :string
    attribute :uri, :string

    xml do
      element "NamespaceBindingType"
      namespace ::Metaschema::Namespace

      map_attribute "prefix", to: :prefix
      map_attribute "uri", to: :uri
    end
  end
end
