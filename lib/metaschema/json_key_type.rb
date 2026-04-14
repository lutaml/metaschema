# frozen_string_literal: true

module Metaschema
  class JsonKeyType < Lutaml::Model::Serializable
    attribute :flag_ref, :string

    xml do
      element "JsonKeyType"
      namespace ::Metaschema::Namespace

      map_attribute "flag-ref", to: :flag_ref
    end
  end
end
