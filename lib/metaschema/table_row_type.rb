require "lutaml/model"

require_relative "table_cell_type"

module Metaschema
  class TableRowType < Lutaml::Model::Serializable
    attribute :td, TableCellType, collection: true
    attribute :th, TableCellType, collection: true

    xml do
      root "tableRowType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_element "td", to: :td
      map_element "th", to: :th
    end
  end
end
