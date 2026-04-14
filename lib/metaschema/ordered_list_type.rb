# frozen_string_literal: true

module Metaschema
  class ListItemType < Lutaml::Model::Serializable; end

  class OrderedListType < Lutaml::Model::Serializable
    attribute :start, :integer
    attribute :li, ListItemType, collection: true

    xml do
      element "orderedListType"
      namespace ::Metaschema::Namespace

      map_attribute "start", to: :start
      map_element "li", to: :li
    end
  end
end
