require "lutaml/model"

require_relative "import"
require_relative "namespace_binding_type"
require_relative "remarks_type"
require_relative "scope"

module Metaschema
  class METASCHEMACONSTRAINTS < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :version, :string
    attribute :import, Import, collection: true
    attribute :namespace_binding, NamespaceBindingType, collection: true
    attribute :scope, Scope, collection: true
    attribute :remarks, RemarksType

    xml do
      root "METASCHEMA-CONSTRAINTS"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

      map_element "name", to: :name
      map_element "version", to: :version
      map_element "import", to: :import
      map_element "namespace-binding", to: :namespace_binding
      map_element "scope", to: :scope
      map_element "remarks", to: :remarks
    end
  end
end
