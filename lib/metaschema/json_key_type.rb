require "lutaml/model"

module Metaschema
  class JsonKeyType < Lutaml::Model::Serializable
    attribute :flag_ref, :string

    xml do
      root "JsonKeyType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "flag-ref", to: :flag_ref
    end
  end
end
