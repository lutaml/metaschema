# frozen_string_literal: true

require 'lutaml/model'

require_relative 'remarks_type'

module Metaschema
  class KeyField < Lutaml::Model::Serializable
    attribute :target, :string
    attribute :pattern, :string
    attribute :remarks, RemarksType

    xml do
      root 'key-field'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'target', to: :target
      map_attribute 'pattern', to: :pattern
      map_element 'remarks', to: :remarks
    end
  end
end
