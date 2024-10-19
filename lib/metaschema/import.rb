require "lutaml/model"

module Metaschema
  class Import < Lutaml::Model::Serializable
    attribute :href, :string

    xml do
      root "import"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "href", to: :href
    end
  end
end
