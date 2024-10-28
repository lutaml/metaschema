# frozen_string_literal: true

require 'lutaml/model'

module Metaschema
  class InsertType < Lutaml::Model::Serializable
    attribute :type, :string
    attribute :id_ref, :string

    xml do
      root 'insertType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'type', to: :type
      map_attribute 'id-ref', to: :id_ref
    end
  end
end
