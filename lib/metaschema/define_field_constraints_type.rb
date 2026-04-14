# frozen_string_literal: true

module Metaschema
  class DefineFieldConstraintsType < Lutaml::Model::Serializable
    attribute :let, ConstraintLetType, collection: true
    attribute :allowed_values, TargetedAllowedValuesConstraintType,
              collection: true
    attribute :matches, TargetedMatchesConstraintType, collection: true
    attribute :index_has_key, TargetedIndexHasKeyConstraintType,
              collection: true
    attribute :expect, TargetedExpectConstraintType, collection: true
    attribute :remarks, RemarksType

    xml do
      element "DefineFieldConstraintsType"
      mixed_content
      namespace ::Metaschema::Namespace

      map_element "let", to: :let
      map_element "allowed-values", to: :allowed_values
      map_element "matches", to: :matches
      map_element "index-has-key", to: :index_has_key
      map_element "expect", to: :expect
      map_element "remarks", to: :remarks
    end
  end
end
