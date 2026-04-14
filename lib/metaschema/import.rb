# frozen_string_literal: true

module Metaschema
  class Import < Lutaml::Model::Serializable
    attribute :href, :string

    xml do
      element "import"
      namespace ::Metaschema::Namespace

      map_attribute "href", to: :href
    end
  end
end
