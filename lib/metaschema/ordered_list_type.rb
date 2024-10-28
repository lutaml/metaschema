# frozen_string_literal: true

require 'lutaml/model'

# require_relative "list_item_type"

module Metaschema
  class ListItemType < Lutaml::Model::Serializable; end

  class OrderedListType < Lutaml::Model::Serializable
    attribute :start, :integer
    attribute :li, ListItemType, collection: true

    xml do
      root 'orderedListType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'start', to: :start
      map_element 'li', to: :li
    end
  end
end
