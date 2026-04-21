# frozen_string_literal: true

require "json"

module Metaschema
  # Generates JSON Schema (draft-07) from a parsed Metaschema document.
  #
  # Usage:
  #   ms = Metaschema::Root.from_xml(File.read("metaschema.xml"))
  #   schema = JsonSchemaGenerator.generate(ms)
  #   puts JSON.pretty_generate(schema)
  #
  # The generator walks the metaschema definition tree and emits a JSON Schema
  # with a top-level object for each root assembly, and shared $defs for all
  # referenced types.
  class JsonSchemaGenerator
    SCHEMA_URI = "http://json-schema.org/draft-07/schema#"

    # Maps metaschema as-type to JSON Schema type.
    TYPE_MAP = {
      "string" => { "type" => "string" },
      "markup-line" => { "type" => "string" },
      "markup-multiline" => { "type" => "string" },
      "boolean" => { "type" => "boolean" },
      "integer" => { "type" => "integer" },
      "positive-integer" => { "type" => "integer", "minimum" => 1 },
      "non-negative-integer" => { "type" => "integer", "minimum" => 0 },
      "decimal" => { "type" => "number" },
      "date" => { "type" => "string", "format" => "date" },
      "date-time" => { "type" => "string", "format" => "date-time" },
      "dateTime" => { "type" => "string", "format" => "date-time" },
      "dateTime-with-timezone" => { "type" => "string",
                                    "format" => "date-time" },
      "uri" => { "type" => "string", "format" => "uri" },
      "uri-reference" => { "type" => "string" },
      "uuid" => { "type" => "string",
                  "pattern" => "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" },
      "base64" => { "type" => "string", "contentEncoding" => "base64" },
      "token" => { "type" => "string" },
      "email" => { "type" => "string", "format" => "email" },
      "ip-v4-address" => { "type" => "string", "format" => "ipv4" },
      "ip-v6-address" => { "type" => "string", "format" => "ipv6" },
    }.freeze

    def self.generate(metaschema, id: nil)
      new(metaschema, id: id).generate
    end

    def initialize(metaschema, id: nil)
      @metaschema = metaschema
      @id = id
      @definitions = {}
      @field_defs = {}
      @assembly_defs = {}
      @flag_defs = {}
    end

    def generate
      collect_definitions

      @metaschema.define_assembly&.each { |a| build_assembly_schema(a) }
      @metaschema.define_field&.each { |f| build_field_def_schema(f) }
      @metaschema.define_flag&.each { |f| build_flag_schema(f) }

      root_assemblies = (@metaschema.define_assembly || []).select do |a|
        a.root_name&.content
      end
      if root_assemblies.one?
        root = root_assemblies.first
        root_name = root.root_name.content
        @definitions[root.name] || { "type" => "object" }

        schema = {
          "$schema" => SCHEMA_URI,
          "$id" => @id,
          "type" => "object",
          "properties" => { root_name => { "$ref" => "#/$defs/#{root.name}" } },
          "required" => [root_name],
          "additionalProperties" => false,
          "$defs" => @definitions,
        }
        schema.delete("$id") unless @id
        schema
      else
        {
          "$schema" => SCHEMA_URI,
          "$id" => @id,
          "$defs" => @definitions,
        }.compact
      end
    end

    private

    def collect_definitions
      @metaschema.define_assembly&.each do |a|
        @assembly_defs[a.name] = a if a.name
      end
      @metaschema.define_field&.each { |f| @field_defs[f.name] = f if f.name }
      @metaschema.define_flag&.each { |f| @flag_defs[f.name] = f if f.name }
    end

    # ── Assembly ───────────────────────────────────────────────────────

    def build_assembly_schema(assembly_def)
      return @definitions[assembly_def.name] if @definitions.key?(assembly_def.name)

      # Placeholder to prevent cycles
      @definitions[assembly_def.name] = { "type" => "object" }

      props = {}
      required = []
      pattern_props = {}

      # Flags → object properties
      (assembly_def.define_flag || []).each do |fl|
        name = fl.name
        next unless name

        props[name] = build_flag_type_schema(fl)
        required << name if fl.required == "yes"
      end

      (assembly_def.flag || []).each do |fr|
        ref = fr.ref
        next unless ref

        fd = @flag_defs[ref]
        next unless fd

        props[ref] = build_flag_type_schema(fd)
        required << ref if fr.required == "yes"
      end

      # Model children
      if assembly_def.model
        model = assembly_def.model
        collect_model_children(model, props, required, pattern_props)
      end

      schema = { "type" => "object", "properties" => props }
      schema["required"] = required unless required.empty?
      schema["additionalProperties"] = false
      schema["patternProperties"] = pattern_props unless pattern_props.empty?

      if assembly_def.formal_name && !assembly_def.formal_name.is_a?(TrueClass)
        title = assembly_def.formal_name.is_a?(String) ? assembly_def.formal_name : assembly_def.formal_name.content
        schema["title"] = title if title && !title.empty?
      end
      if assembly_def.description.respond_to?(:content)
        desc = assembly_def.description.content
        schema["description"] = desc if desc && !desc.empty?
      end

      @definitions[assembly_def.name] = schema
    end

    def collect_model_children(model, props, required, pattern_props)
      (model.field || []).each do |fr|
        add_field_ref(fr, props, required, pattern_props)
      end
      (model.assembly || []).each do |ar|
        add_assembly_ref(ar, props, required, pattern_props)
      end
      (model.define_field || []).each do |fd|
        add_inline_field(fd, props, required)
      end
      (model.define_assembly || []).each do |ad|
        add_inline_assembly(ad, props, required)
      end
      (model.choice || []).each do |c|
        collect_choice_children(c, props, required, pattern_props)
      end
      (model.choice_group || []).each do |cg|
        collect_choice_group_children(cg, props, required, pattern_props)
      end
    end

    def collect_choice_children(choice, props, required, pattern_props)
      (choice.field || []).each do |fr|
        add_field_ref(fr, props, required, pattern_props)
      end
      (choice.assembly || []).each do |ar|
        add_assembly_ref(ar, props, required, pattern_props)
      end
      (choice.define_field || []).each do |fd|
        add_inline_field(fd, props, required)
      end
      (choice.define_assembly || []).each do |ad|
        add_inline_assembly(ad, props, required)
      end
    end

    def collect_choice_group_children(cg, props, _required, pattern_props)
      group_as = cg.group_as
      json_name = group_as&.name

      child_field_refs = cg.field || []
      child_asm_refs = cg.assembly || []

      if group_as&.in_json == "BY_KEY" && json_name
        # BY_KEY: object with pattern properties
        inner_props = {}
        child_field_refs.each do |fr|
          ref = fr.ref
          fd = @field_defs[ref]
          inner_props.merge!(build_field_by_key_schema(fd)) if fd
        end
        pattern_props[json_name] = inner_props unless inner_props.empty?
      elsif group_as&.in_json == "ARRAY" && json_name && child_field_refs.one?
        # Array of single field type
        fr = child_field_refs.first
        ref = fr.ref
        fd = @field_defs[ref]
        if fd
          items = build_field_items_schema(fd)
          props[json_name] = { "type" => "array", "items" => items }
        end
      elsif group_as&.in_json == "ARRAY" && json_name && child_asm_refs.one?
        ar = child_asm_refs.first
        ref = ar.ref
        props[json_name] =
          { "type" => "array", "items" => { "$ref" => "#/$defs/#{ref}" } }
        build_assembly_schema(@assembly_defs[ref]) if @assembly_defs[ref]
      end
    end

    # ── Field Ref ──────────────────────────────────────────────────────

    def add_field_ref(fr, props, required, pattern_props)
      ref = fr.ref
      return unless ref

      fd = @field_defs[ref]
      return unless fd

      group_as = fr.group_as
      json_name = fr.use_name&.content || group_as&.name || ref

      if group_as&.in_json == "BY_KEY"
        key_flag = fd.json_key&.flag_ref
        if key_flag
          inner = build_field_object_schema(fd)
          pattern_props[".*"] = inner
        end
      elsif group_as && %w[ARRAY SINGLETON_OR_ARRAY].include?(group_as.in_json)
        items = build_field_items_schema(fd)
        arr = { "type" => "array", "items" => items }
        if group_as.in_json == "SINGLETON_OR_ARRAY"
          arr = { "oneOf" => [items, arr] }
        end
        props[json_name] = arr
      else
        # Singleton field
        has_flags = (fd.define_flag || []).any? || (fd.flag || []).any?
        has_vk = fd.json_value_key || fd.json_value_key_flag
        props[json_name] = if has_flags || has_vk
                             build_field_object_schema(fd)
                           else
                             build_field_scalar_schema(fd)
                           end
      end

      required << json_name if fr.min_occurs&.to_i&.> 0
    end

    # ── Assembly Ref ───────────────────────────────────────────────────

    def add_assembly_ref(ar, props, required, _pattern_props)
      ref = ar.ref
      return unless ref

      build_assembly_schema(@assembly_defs[ref]) if @assembly_defs[ref]

      group_as = ar.group_as
      json_name = group_as&.name || ref

      if group_as&.in_json == "BY_KEY"
        # BY_KEY: object whose keys are dynamic
        props[json_name] = {
          "type" => "object",
          "additionalProperties" => { "$ref" => "#/$defs/#{ref}" },
        }
      elsif group_as && %w[ARRAY SINGLETON_OR_ARRAY].include?(group_as.in_json)
        arr = { "type" => "array", "items" => { "$ref" => "#/$defs/#{ref}" } }
        if group_as.in_json == "SINGLETON_OR_ARRAY"
          arr = { "oneOf" => [{ "$ref" => "#/$defs/#{ref}" }, arr] }
        end
        props[json_name] = arr
      else
        props[json_name] = { "$ref" => "#/$defs/#{ref}" }
      end

      required << json_name if ar.min_occurs&.to_i&.> 0
    end

    # ── Inline Definitions ─────────────────────────────────────────────

    def add_inline_field(fd, props, _required)
      return unless fd.name

      name = fd.name
      props[name] = build_field_scalar_schema(fd)
    end

    def add_inline_assembly(ad, props, _required)
      return unless ad.name

      name = ad.name
      build_assembly_schema(ad) if ad.model
      props[name] = { "$ref" => "#/$defs/#{ad.name}" }
    end

    # ── Field Schema Builders ──────────────────────────────────────────

    def build_field_scalar_schema(fd)
      schema = type_for(fd.as_type)
      apply_field_constraints(schema, fd)
      schema
    end

    def build_field_items_schema(fd)
      has_flags = (fd.define_flag || []).any? || (fd.flag || []).any?
      if has_flags
        build_field_object_schema(fd)
      else
        build_field_scalar_schema(fd)
      end
    end

    def build_field_object_schema(fd)
      obj = { "type" => "object", "properties" => {} }
      required = []
      value_key = fd.json_value_key || "STRVALUE"

      # Value property
      value_schema = type_for(fd.as_type)
      apply_field_constraints(value_schema, fd)
      obj["properties"][value_key] = value_schema
      required << value_key

      # Flags
      (fd.define_flag || []).each do |fl|
        next unless fl.name

        obj["properties"][fl.name] = build_flag_type_schema(fl)
        required << fl.name if fl.required == "yes"
      end

      (fd.flag || []).each do |fr|
        next unless fr.ref

        fdef = @flag_defs[fr.ref]
        obj["properties"][fr.ref] =
          fdef ? build_flag_type_schema(fdef) : { "type" => "string" }
        required << fr.ref if fr.required == "yes"
      end

      obj["required"] = required unless required.empty?
      obj["additionalProperties"] = false
      obj
    end

    def build_field_by_key_schema(fd)
      build_field_object_schema(fd)
    end

    # ── Field Schema Builder (standalone definitions) ──────────────────

    def build_field_def_schema(fd)
      return @definitions[fd.name] if @definitions.key?(fd.name)

      has_flags = (fd.define_flag || []).any? || (fd.flag || []).any?
      schema = if has_flags
                 build_field_object_schema(fd)
               else
                 build_field_scalar_schema(fd)
               end

      if fd.formal_name && !fd.formal_name.is_a?(TrueClass)
        title = fd.formal_name.is_a?(String) ? fd.formal_name : fd.formal_name.content
        schema["title"] = title if title && !title.empty?
      end
      if fd.description.respond_to?(:content)
        desc = fd.description.content
        schema["description"] = desc if desc && !desc.empty?
      end

      @definitions[fd.name] = schema
    end

    # ── Flag Schema Builders ───────────────────────────────────────────

    def build_flag_schema(flag_def)
      return @definitions[flag_def.name] if @definitions.key?(flag_def.name)

      schema = build_flag_type_schema(flag_def)
      @definitions[flag_def.name] = schema
      schema
    end

    def build_flag_type_schema(flag_or_def)
      schema = type_for(flag_or_def.as_type)

      # Apply constraints
      constraint = flag_or_def.constraint
      if constraint
        apply_allowed_values(schema, constraint.allowed_values)
        apply_matches(schema, constraint.matches)
      end

      if flag_or_def.formal_name && !flag_or_def.formal_name.is_a?(TrueClass)
        title = flag_or_def.formal_name.is_a?(String) ? flag_or_def.formal_name : flag_or_def.formal_name.content
        schema["title"] = title if title && !title.empty?
      end
      if flag_or_def.description.respond_to?(:content)
        desc = flag_or_def.description.content
        schema["description"] = desc if desc && !desc.empty?
      end
      schema
    end

    # ── Constraints ────────────────────────────────────────────────────

    def apply_field_constraints(schema, fd)
      constraint = fd.constraint
      return unless constraint

      apply_allowed_values(schema, constraint.allowed_values)
      apply_matches(schema, constraint.matches)
    end

    def apply_allowed_values(schema, constraints)
      return unless constraints

      Array(constraints).each do |c|
        enum_values = Array(c.enum).filter_map(&:value)
        schema["enum"] = enum_values unless enum_values.empty?
      end
    end

    def apply_matches(schema, constraints)
      return unless constraints

      Array(constraints).each do |c|
        schema["pattern"] = c.regex if c.regex
      end
    end

    # ── Type Mapping ───────────────────────────────────────────────────

    def type_for(as_type)
      TYPE_MAP[as_type]&.dup || { "type" => "string" }
    end
  end
end
