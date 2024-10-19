require "lutaml/model"

module Metaschema
  class MetaschemaImportType < Lutaml::Model::Serializable
    attribute :href, :string

    xml do
      root "MetaschemaImportType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "href", to: :href
    end
  end
end
