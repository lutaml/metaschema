require "lutaml/model"

module Metaschema
  class JsonValueKeyFlagType < Lutaml::Model::Serializable
    attribute :flag_ref, :string

    xml do
      root "JsonValueKeyFlagType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0", "xmlns"

      map_attribute "flag-ref", to: :flag_ref
    end
  end
end
