require "lutaml/model"

module Metaschema
  class RootName < Lutaml::Model::Serializable
    attribute :content, :string
    attribute :index, :integer

    xml do
      root "root-name"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0", "xmlns"

      map_content to: :content
      map_attribute "index", to: :index
    end
  end
end
