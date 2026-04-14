# frozen_string_literal: true

module Metaschema
  class UseNameType < Lutaml::Model::Serializable
    attribute :content, :string
    attribute :index, :integer

    xml do
      element "UseNameType"
      namespace ::Metaschema::Namespace

      map_content to: :content
      map_attribute "index", to: :index
    end
  end
end
