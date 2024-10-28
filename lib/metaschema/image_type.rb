# frozen_string_literal: true

require 'lutaml/model'

module Metaschema
  class ImageType < Lutaml::Model::Serializable
    attribute :alt, :string
    attribute :src, :string
    attribute :title, :string

    xml do
      root 'imageType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'alt', to: :alt
      map_attribute 'src', to: :src
      map_attribute 'title', to: :title
    end
  end
end
