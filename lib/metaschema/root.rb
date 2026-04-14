# frozen_string_literal: true

module Metaschema
  class Root < Lutaml::Model::Serializable
    attribute :abstract, :string, default: -> { "no" }
    attribute :schema_name, MarkupLineDatatype
    attribute :schema_version, SchemaVersion
    attribute :short_name, ShortName
    attribute :namespace, NamespaceValue
    attribute :json_base_uri, JsonBaseUri
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType
    attribute :import, MetaschemaImportType, collection: true
    attribute :namespace_binding, NamespaceBindingType, collection: true
    attribute :define_assembly, GlobalAssemblyDefinitionType, collection: true
    attribute :define_field, GlobalFieldDefinitionType, collection: true
    attribute :define_flag, GlobalFlagDefinitionType, collection: true

    xml do
      element "METASCHEMA"
      ordered
      namespace ::Metaschema::Namespace

      map_attribute "abstract", to: :abstract
      map_element "schema-name", to: :schema_name
      map_element "schema-version", to: :schema_version
      map_element "short-name", to: :short_name
      map_element "namespace", to: :namespace
      map_element "json-base-uri", to: :json_base_uri
      map_element "prop", to: :prop
      map_element "remarks", to: :remarks
      map_element "import", to: :import
      map_element "namespace-binding", to: :namespace_binding
      map_element "define-assembly", to: :define_assembly
      map_element "define-field", to: :define_field
      map_element "define-flag", to: :define_flag
    end
  end
end
