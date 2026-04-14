# frozen_string_literal: true

module Metaschema
  class ListType < Lutaml::Model::Serializable
    attribute :li, ListItemType, collection: true

    xml do
      element "listType"
      namespace ::Metaschema::Namespace

      map_element "li", to: :li
    end
  end
end
