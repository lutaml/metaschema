# frozen_string_literal: true

module Metaschema
  class Scope < Lutaml::Model::Serializable
    attribute :metaschema_namespace, :string
    attribute :metaschema_short_name, :string
    attribute :assembly, Assembly, collection: true
    attribute :field, Field, collection: true
    attribute :flag, Flag, collection: true

    xml do
      element "scope"
      namespace ::Metaschema::Namespace

      map_attribute "metaschema-namespace", to: :metaschema_namespace
      map_attribute "metaschema-short-name", to: :metaschema_short_name
      map_element "field", to: :field
      map_element "assembly", to: :assembly
      map_element "flag", to: :flag
    end
  end
end
