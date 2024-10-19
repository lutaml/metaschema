require "lutaml/model"

require_relative "list_item_type"

module Metaschema
  class ListType < Lutaml::Model::Serializable
    attribute :li, ListItemType, collection: true

    xml do
      root "listType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_element "li", to: :li
    end
  end
end
