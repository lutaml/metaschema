# frozen_string_literal: true

module Metaschema
  class JsonValueKeyFlagType < Lutaml::Model::Serializable
    attribute :flag_ref, :string

    xml do
      element "JsonValueKeyFlagType"
      namespace ::Metaschema::Namespace

      map_attribute "flag-ref", to: :flag_ref
    end
  end
end
