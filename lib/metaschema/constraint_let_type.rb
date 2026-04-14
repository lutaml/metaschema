# frozen_string_literal: true

module Metaschema
  class ConstraintLetType < Lutaml::Model::Serializable
    attribute :var, :string
    attribute :expression, :string
    attribute :remarks, RemarksType

    xml do
      element "ConstraintLetType"
      namespace ::Metaschema::Namespace

      map_attribute "var", to: :var
      map_attribute "expression", to: :expression
      map_element "remarks", to: :remarks
    end
  end
end
