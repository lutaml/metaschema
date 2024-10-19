require "lutaml/model"

module Metaschema
  class UseNameType < Lutaml::Model::Serializable
    attribute :content, :string
    attribute :index, :integer

    xml do
      root "UseNameType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_content to: :content
      map_attribute "index", to: :index
    end
  end
end
