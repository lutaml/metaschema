# frozen_string_literal: true

module Metaschema
  class ImageType < Lutaml::Model::Serializable
    attribute :alt, :string
    attribute :src, :string
    attribute :title, :string

    xml do
      element "imageType"
      namespace ::Metaschema::Namespace

      map_attribute "alt", to: :alt
      map_attribute "src", to: :src
      map_attribute "title", to: :title
    end
  end
end
