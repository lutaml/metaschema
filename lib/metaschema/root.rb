require "lutaml/model"

require_relative "global_assembly_definition_type"
require_relative "global_field_definition_type"
require_relative "global_flag_definition_type"
require_relative "markup_line_datatype"
require_relative "metaschema_import_type"
require_relative "namespace_binding_type"
require_relative "property_type"
require_relative "remarks_type"

module Metaschema
  class Root < Lutaml::Model::Serializable
    attribute :abstract, :string, default: -> { "no" }
    attribute :schema_name, MarkupLineDatatype
    attribute :schema_version, :string
    attribute :short_name, :string
    attribute :namespace, :string
    attribute :json_base_uri, :string
    attribute :prop, PropertyType, collection: true
    attribute :remarks, RemarksType
    attribute :import, MetaschemaImportType, collection: true
    attribute :namespace_binding, NamespaceBindingType, collection: true
    attribute :define_assembly, GlobalAssemblyDefinitionType, collection: true
    attribute :define_field, GlobalFieldDefinitionType, collection: true
    attribute :define_flag, GlobalFlagDefinitionType, collection: true

    xml do
      root "METASCHEMA"
      namespace "http://csrc.nist.gov/ns/oscal/metaschema/1.0"

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
