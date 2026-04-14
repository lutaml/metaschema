# frozen_string_literal: true

module Metaschema
  class InsertType < Lutaml::Model::Serializable
    attribute :type, :string
    attribute :id_ref, :string

    xml do
      element "insertType"
      namespace ::Metaschema::Namespace

      map_attribute "type", to: :type
      map_attribute "id-ref", to: :id_ref
    end
  end
end
