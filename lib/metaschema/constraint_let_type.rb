require "lutaml/model"

require_relative "remarks_type"

module Metaschema
  class ConstraintLetType < Lutaml::Model::Serializable
    attribute :var, :string
    attribute :expression, :string
    attribute :remarks, RemarksType

    xml do
      root "ConstraintLetType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "var", to: :var
      map_attribute "expression", to: :expression
      map_element "remarks", to: :remarks
    end
  end
end
