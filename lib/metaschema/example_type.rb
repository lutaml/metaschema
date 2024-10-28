# frozen_string_literal: true

require 'lutaml/model'

require_relative 'markup_line_datatype'
require_relative 'remarks_type'

module Metaschema
  class ExampleType < Lutaml::Model::Serializable
    attribute :href, :string
    attribute :path, :string
    attribute :description, MarkupLineDatatype
    attribute :remarks, RemarksType

    xml do
      root 'ExampleType'
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_attribute 'href', to: :href
      map_attribute 'path', to: :path
      map_element 'description', to: :description
      map_element 'remarks', to: :remarks
    end
  end
end
