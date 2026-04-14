# frozen_string_literal: true

module Metaschema
  class MetaschemaConstraints < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :version, :string
    attribute :import, Import, collection: true
    attribute :namespace_binding, NamespaceBindingType, collection: true
    attribute :scope, Scope, collection: true
    attribute :remarks, RemarksType

    xml do
      element "METASCHEMA-CONSTRAINTS"
      namespace ::Metaschema::Namespace

      map_element "name", to: :name
      map_element "version", to: :version
      map_element "import", to: :import
      map_element "namespace-binding", to: :namespace_binding
      map_element "scope", to: :scope
      map_element "remarks", to: :remarks
    end
  end
end
