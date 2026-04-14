# frozen_string_literal: true

module Metaschema
  class TableRowType < Lutaml::Model::Serializable
    attribute :td, TableCellType, collection: true
    attribute :th, TableCellType, collection: true

    xml do
      element "tableRowType"
      namespace ::Metaschema::Namespace

      map_element "td", to: :td
      map_element "th", to: :th
    end
  end
end
