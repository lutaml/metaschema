# frozen_string_literal: true

module Metaschema
  class ExampleType < Lutaml::Model::Serializable
    attribute :href, :string
    attribute :path, :string
    attribute :description, MarkupLineDatatype
    attribute :remarks, RemarksType

    xml do
      element "ExampleType"
      namespace ::Metaschema::Namespace

      map_attribute "href", to: :href
      map_attribute "path", to: :path
      map_element "description", to: :description
      map_element "remarks", to: :remarks
    end
  end
end
