# frozen_string_literal: true

require "nokogiri"
require "lutaml/model"

module Metaschema
  class Error < StandardError; end

  def self.validate(file_path)
    root = Root.from_file(file_path)
    root.validate_verbose
  end

  autoload :AllowedValueType, "metaschema/allowed_value_type"
  autoload :AllowedValuesType, "metaschema/allowed_values_type"
  autoload :AnchorType, "metaschema/anchor_type"
  autoload :AnyType, "metaschema/any_type"
  autoload :Assembly, "metaschema/assembly"
  autoload :AssemblyModelType, "metaschema/assembly_model_type"
  autoload :AssemblyReferenceType, "metaschema/assembly_reference_type"
  autoload :BlockQuoteType, "metaschema/block_quote_type"
  autoload :ChoiceType, "metaschema/choice_type"
  autoload :CodeType, "metaschema/code_type"
  autoload :ConstraintLetType, "metaschema/constraint_let_type"
  autoload :DefineAssemblyConstraintsType,
           "metaschema/define_assembly_constraints_type"
  autoload :DefineFieldConstraintsType,
           "metaschema/define_field_constraints_type"
  autoload :DefineFlagConstraintsType, "metaschema/define_flag_constraints_type"
  autoload :ExampleType, "metaschema/example_type"
  autoload :ExpectConstraintType, "metaschema/expect_constraint_type"
  autoload :Field, "metaschema/field"
  autoload :FieldReferenceType, "metaschema/field_reference_type"
  autoload :Flag, "metaschema/flag"
  autoload :FlagReferenceType, "metaschema/flag_reference_type"
  autoload :GlobalAssemblyDefinitionType,
           "metaschema/global_assembly_definition_type"
  autoload :GlobalFieldDefinitionType, "metaschema/global_field_definition_type"
  autoload :GlobalFlagDefinitionType, "metaschema/global_flag_definition_type"
  autoload :GroupAsType, "metaschema/group_as_type"
  autoload :GroupedAssemblyReferenceType,
           "metaschema/grouped_assembly_reference_type"
  autoload :GroupedChoiceType, "metaschema/grouped_choice_type"
  autoload :GroupedFieldReferenceType, "metaschema/grouped_field_reference_type"
  autoload :GroupedInlineAssemblyDefinitionType,
           "metaschema/grouped_inline_assembly_definition_type"
  autoload :GroupedInlineFieldDefinitionType,
           "metaschema/grouped_inline_field_definition_type"
  autoload :ImageType, "metaschema/image_type"
  autoload :Import, "metaschema/import"
  autoload :IndexHasKeyConstraintType,
           "metaschema/index_has_key_constraint_type"
  autoload :InlineAssemblyDefinitionType,
           "metaschema/inline_assembly_definition_type"
  autoload :InlineFieldDefinitionType, "metaschema/inline_field_definition_type"
  autoload :InlineFlagDefinitionType, "metaschema/inline_flag_definition_type"
  autoload :InlineMarkupType, "metaschema/inline_markup_type"
  autoload :InsertType, "metaschema/insert_type"
  autoload :JsonKeyType, "metaschema/json_key_type"
  autoload :JsonValueKey, "metaschema/json_value_key"
  autoload :JsonValueKeyFlagType, "metaschema/json_value_key_flag_type"
  autoload :KeyField, "metaschema/key_field"
  autoload :ListItemType, "metaschema/list_item_type"
  autoload :ListType, "metaschema/list_type"
  autoload :MarkupLineDatatype, "metaschema/markup_line_datatype"
  autoload :MatchesConstraintType, "metaschema/matches_constraint_type"
  autoload :MetaschemaImportType, "metaschema/metaschema_import_type"
  autoload :MetaschemaConstraints, "metaschema/metaschema_constraints"
  autoload :Namespace, "metaschema/namespace"
  autoload :NamespaceValue, "metaschema/namespace_value"
  autoload :JsonBaseUri, "metaschema/json_base_uri"
  autoload :NamespaceBindingType, "metaschema/namespace_binding_type"
  autoload :OrderedListType, "metaschema/ordered_list_type"
  autoload :PreformattedType, "metaschema/preformatted_type"
  autoload :PropertyType, "metaschema/property_type"
  autoload :RemarksType, "metaschema/remarks_type"
  autoload :Root, "metaschema/root"
  autoload :RootName, "metaschema/root_name"
  autoload :Scope, "metaschema/scope"
  autoload :TableCellType, "metaschema/table_cell_type"
  autoload :TableRowType, "metaschema/table_row_type"
  autoload :TableType, "metaschema/table_type"
  autoload :TargetedAllowedValuesConstraintType,
           "metaschema/targeted_allowed_values_constraint_type"
  autoload :TargetedExpectConstraintType,
           "metaschema/targeted_expect_constraint_type"
  autoload :TargetedHasCardinalityConstraintType,
           "metaschema/targeted_has_cardinality_constraint_type"
  autoload :TargetedIndexConstraintType,
           "metaschema/targeted_index_constraint_type"
  autoload :TargetedIndexHasKeyConstraintType,
           "metaschema/targeted_index_has_key_constraint_type"
  autoload :TargetedKeyConstraintType, "metaschema/targeted_key_constraint_type"
  autoload :TargetedMatchesConstraintType,
           "metaschema/targeted_matches_constraint_type"
  autoload :UseNameType, "metaschema/use_name_type"
  autoload :FormalName, "metaschema/formal_name"
  autoload :SchemaVersion, "metaschema/schema_version"
  autoload :ShortName, "metaschema/short_name"
  autoload :AugmentType, "metaschema/augment_type"
  autoload :ConstraintValidator, "metaschema/constraint_validator"
  autoload :JsonSchemaGenerator, "metaschema/json_schema_generator"
  autoload :MarkdownDocGenerator, "metaschema/markdown_doc_generator"
  autoload :MetapathEvaluator, "metaschema/metapath_evaluator"
  autoload :ModelGenerator, "metaschema/model_generator"
  autoload :RubySourceEmitter, "metaschema/ruby_source_emitter"
  autoload :TypeMapper, "metaschema/type_mapper"
end
