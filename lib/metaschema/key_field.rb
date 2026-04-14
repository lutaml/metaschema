# frozen_string_literal: true

module Metaschema
  class KeyField < Lutaml::Model::Serializable
    attribute :target, :string
    attribute :pattern, :string
    attribute :remarks, RemarksType

    xml do
      element "key-field"
      namespace ::Metaschema::Namespace

      map_attribute "target", to: :target
      map_attribute "pattern", to: :pattern
      map_element "remarks", to: :remarks
    end
  end
end
