require "lutaml/model"

module Metaschema
  class AnyType < Lutaml::Model::Serializable
    xml do
      root "AnyType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"
    end
  end
end
