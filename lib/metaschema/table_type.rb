require "lutaml/model"

require_relative "table_row_type"

module Metaschema
  class TableType < Lutaml::Model::Serializable
    attribute :tr, TableRowType, collection: true

    xml do
      root "tableType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_element "tr", to: :tr
    end
  end
end
