# frozen_string_literal: true

module Metaschema
  class Flag < Lutaml::Model::Serializable
    attribute :target, :string
    attribute :let, ConstraintLetType, collection: true
    attribute :allowed_values, AllowedValuesType, collection: true
    attribute :matches, MatchesConstraintType, collection: true
    attribute :index_has_key, IndexHasKeyConstraintType, collection: true
    attribute :expect, ExpectConstraintType, collection: true
    attribute :remarks, RemarksType

    xml do
      element "flag"
      namespace ::Metaschema::Namespace

      map_attribute "target", to: :target
      map_element "let", to: :let
      map_element "allowed-values", to: :allowed_values
      map_element "matches", to: :matches
      map_element "index-has-key", to: :index_has_key
      map_element "expect", to: :expect
      map_element "remarks", to: :remarks
    end
  end
end
