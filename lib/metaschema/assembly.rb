# frozen_string_literal: true

module Metaschema
  class Assembly < Lutaml::Model::Serializable
    attribute :target, :string
    attribute :let, ConstraintLetType, collection: true
    attribute :allowed_values, TargetedAllowedValuesConstraintType,
              collection: true
    attribute :matches, TargetedMatchesConstraintType, collection: true
    attribute :index_has_key, TargetedIndexHasKeyConstraintType,
              collection: true
    attribute :expect, TargetedExpectConstraintType, collection: true
    attribute :index, TargetedIndexConstraintType, collection: true
    attribute :is_unique, TargetedKeyConstraintType, collection: true
    attribute :has_cardinality, TargetedHasCardinalityConstraintType,
              collection: true
    attribute :remarks, RemarksType

    xml do
      element "assembly"
      namespace ::Metaschema::Namespace

      map_attribute "target", to: :target
      map_element "let", to: :let
      map_element "is-unique", to: :is_unique
      map_element "allowed-values", to: :allowed_values
      map_element "matches", to: :matches
      map_element "index-has-key", to: :index_has_key
      map_element "expect", to: :expect
      map_element "index", to: :index
      map_element "has-cardinality", to: :has_cardinality
      map_element "remarks", to: :remarks
    end
  end
end
