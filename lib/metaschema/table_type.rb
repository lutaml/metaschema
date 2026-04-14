# frozen_string_literal: true

module Metaschema
  class TableType < Lutaml::Model::Serializable
    attribute :tr, TableRowType, collection: true

    xml do
      element "tableType"
      namespace ::Metaschema::Namespace

      map_element "tr", to: :tr
    end
  end
end
