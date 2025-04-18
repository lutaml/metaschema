# frozen_string_literal: true

require 'lutaml/model'

require_relative 'constraint_let_type'
require_relative 'remarks_type'
require_relative 'targeted_allowed_values_constraint_type'
require_relative 'targeted_expect_constraint_type'
require_relative 'targeted_has_cardinality_constraint_type'
require_relative 'targeted_index_constraint_type'
require_relative 'targeted_index_has_key_constraint_type'
require_relative 'targeted_key_constraint_type'
require_relative 'targeted_matches_constraint_type'

module Metaschema
  class Assembly < Lutaml::Model::Serializable
    attribute :target, :string
    attribute :let, ConstraintLetType, collection: true
    attribute :allowed_values, TargetedAllowedValuesConstraintType, collection: true
    attribute :matches, TargetedMatchesConstraintType, collection: true
    attribute :index_has_key, TargetedIndexHasKeyConstraintType, collection: true
    attribute :expect, TargetedExpectConstraintType, collection: true
    attribute :index, TargetedIndexConstraintType, collection: true
    attribute :is_unique, TargetedKeyConstraintType, collection: true
    attribute :has_cardinality, TargetedHasCardinalityConstraintType, collection: true
    attribute :remarks, RemarksType

    xml do
      root 'assembly'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'target', to: :target
      map_element 'let', to: :let
      map_element 'is-unique', to: :is_unique
      map_element 'allowed-values', to: :allowed_values
      map_element 'matches', to: :matches
      map_element 'index-has-key', to: :index_has_key
      map_element 'expect', to: :expect
      map_element 'index', to: :index
      map_element 'has-cardinality', to: :has_cardinality
      map_element 'remarks', to: :remarks
    end
  end
end
