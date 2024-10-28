# frozen_string_literal: true

require 'lutaml/model'

module Metaschema
  class NamespaceBindingType < Lutaml::Model::Serializable
    attribute :prefix, :string
    attribute :uri, :string

    xml do
      root 'NamespaceBindingType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'prefix', to: :prefix
      map_attribute 'uri', to: :uri
    end
  end
end
