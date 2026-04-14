# frozen_string_literal: true

module Metaschema
  class MetaschemaImportType < Lutaml::Model::Serializable
    attribute :href, :string

    xml do
      element "MetaschemaImportType"
      namespace ::Metaschema::Namespace

      map_attribute "href", to: :href
    end
  end
end
