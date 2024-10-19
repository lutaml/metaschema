require "lutaml/model"

module Metaschema
  class GroupAsType < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :in_json, :string, default: -> { "SINGLETON_OR_ARRAY" }
    attribute :in_xml, :string, default: -> { "UNGROUPED" }

    xml do
      root "GroupAsType"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_attribute "name", to: :name
      map_attribute "in-json", to: :in_json
      map_attribute "in-xml", to: :in_xml
    end
  end
end
