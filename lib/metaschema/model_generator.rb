# frozen_string_literal: true

module Metaschema
  class ModelGenerator
    class << self
      def generate_from_file(metaschema_path, base_path: nil)
        base_path ||= File.dirname(File.expand_path(metaschema_path))
        generate_from_xml(File.read(metaschema_path), base_path: base_path)
      end

      def generate_from_xml(xml_string, base_path: nil)
        metaschema = Metaschema::Root.from_xml(xml_string)
        new.generate(metaschema, base_path: base_path)
      end

      def generate_from_metaschema(metaschema, base_path: nil)
        new.generate(metaschema, base_path: base_path)
      end

      def to_ruby_source(metaschema_path, module_name:, base_path: nil,
split: false)
        classes = generate_from_file(metaschema_path, base_path: base_path)
        emitter = RubySourceEmitter.new(classes, module_name, self)
        split ? emitter.emit_split : emitter.emit
      end
    end

    RESERVED_WORDS = %i[class module method hash object_id nil? is_a? kind_of?
                        instance_of? respond_to? send].freeze

    def generate(metaschema, base_path: nil)
      @classes = {}
      @flag_defs = {}
      @assembly_defs = {}
      @field_defs = {}
      @namespace = metaschema.namespace

      # Resolve imports — merge definitions from imported modules
      resolve_and_merge_imports(metaschema, base_path)

      collect_flag_definitions(metaschema)
      collect_definition_registries(metaschema)

      # Apply augments — add docs/flags to imported definitions
      apply_augments(metaschema)

      # Phase 1: Create field classes for all definitions (top-level + imported)
      @field_defs.each_value do |fd|
        create_field_class(fd) unless @classes.key?("Field_#{safe_attr(fd.name)}")
      end

      # Phase 1: Create assembly placeholders for all definitions (top-level + imported)
      @assembly_defs.each_value do |ad|
        create_assembly_placeholder(ad) unless @classes.key?("Assembly_#{safe_attr(ad.name)}")

        # Phase 2: Populate assembly classes for all definitions
        populate_assembly_class(ad) unless @classes["Assembly_#{safe_attr(ad.name)}"]&.instance_variable_get(:@populated)
      end

      @classes
    end

    private

    def safe_attr(name)
      sym = name.gsub("-", "_").to_sym
      RESERVED_WORDS.include?(sym) ? :"#{sym}_attr" : sym
    end

    # ── Import Resolution ──────────────────────────────────────────────

    def resolve_and_merge_imports(metaschema, base_path)
      imported_defs = resolve_imports(metaschema, base_path)

      # Merge imported definitions — first definition wins (top-level takes priority)
      imported_defs.each do |defs|
        defs[:flags].each { |name, defn| @flag_defs[name] ||= defn }
        defs[:assemblies].each { |name, defn| @assembly_defs[name] ||= defn }
        defs[:fields].each { |name, defn| @field_defs[name] ||= defn }
      end
    end

    def resolve_imports(metaschema, base_path, visited: Set.new)
      imports = metaschema.import
      return [] unless imports && !imports.empty?

      imports.flat_map do |import_elem|
        href = import_elem.href
        next [] unless href

        # Resolve relative to the importing file's directory
        import_path = if base_path
                        File.expand_path(href,
                                         base_path)
                      else
                        File.expand_path(href)
                      end
        next [] unless File.exist?(import_path)

        # Cycle detection — skip already-visited files
        next [] if visited.include?(import_path)

        visited.add(import_path)

        # Parse the imported metaschema
        imported = Metaschema::Root.from_xml(File.read(import_path))

        # Recursively resolve transitive imports
        transitive = resolve_imports(imported, File.dirname(import_path),
                                     visited: visited)

        # Collect definitions from this imported module
        defs = { flags: {}, assemblies: {}, fields: {} }
        imported.define_flag&.each { |f| defs[:flags][f.name] = f if f.name }
        imported.define_assembly&.each do |a|
          defs[:assemblies][a.name] = a if a.name
        end
        imported.define_field&.each { |f| defs[:fields][f.name] = f if f.name }

        transitive + [defs]
      end
    end

    # ── Augment Application ─────────────────────────────────────────────

    def apply_augments(metaschema)
      return unless metaschema.respond_to?(:augment)

      augments = metaschema.augment
      return unless augments && !augments.empty?

      augments.each do |aug|
        name = aug.name
        next unless name

        # Try to find the definition to augment
        target = @assembly_defs[name] || @field_defs[name] || @flag_defs[name]
        next unless target

        # Apply documentation augmentations
        apply_augment_docs(target, aug)
        apply_augment_flags(target, aug)
      end
    end

    def apply_augment_docs(target, augment)
      # Add formal-name if provided and target doesn't have one
      if augment.formal_name && !target.formal_name
        target.formal_name = augment.formal_name
      end

      # Add description if provided and target doesn't have one
      if augment.description && (!target.respond_to?(:description) || !target.description) && target.respond_to?(:description=)
        target.description = augment.description
      end
    end

    def apply_augment_flags(target, augment)
      # Add flag references to assembly/field definitions
      return unless augment.flag&.any? || augment.define_flag&.any?

      # Add flag references
      if target.respond_to?(:flag)
        existing_refs = (target.flag || []).map(&:ref)
        augment.flag.each do |fr|
          next if existing_refs.include?(fr.ref)

          target.flag = (target.flag || []) + [fr]
        end
      end

      # Add inline flag definitions
      if target.respond_to?(:define_flag)
        existing_names = (target.define_flag || []).map(&:name)
        augment.define_flag.each do |fd|
          next if existing_names.include?(fd.name)

          target.define_flag = (target.define_flag || []) + [fd]
        end
      end
    end

    # ── Flag Definitions ──────────────────────────────────────────────

    def collect_flag_definitions(metaschema)
      metaschema.define_flag&.each do |flag_def|
        @flag_defs[flag_def.name] = flag_def if flag_def.name
      end
    end

    def collect_definition_registries(metaschema)
      metaschema.define_assembly&.each do |ad|
        @assembly_defs[ad.name] = ad if ad.name
      end
      metaschema.define_field&.each do |fd|
        @field_defs[fd.name] = fd if fd.name
      end
    end

    # Resolve the XML element name for an assembly reference
    def assembly_xml_element_name(assembly_ref)
      ref_name = assembly_ref.ref
      return ref_name unless ref_name

      # Local override takes priority
      return assembly_ref.use_name.content if assembly_ref.use_name&.content

      # Check definition's use_name
      defn = @assembly_defs[ref_name]
      return defn.use_name.content if defn&.use_name&.content

      ref_name
    end

    # Resolve the XML element name for a field reference
    def field_xml_element_name(field_ref)
      ref_name = field_ref.ref
      return ref_name unless ref_name

      return field_ref.use_name.content if field_ref.use_name&.content

      defn = @field_defs[ref_name]
      return defn.use_name.content if defn&.use_name&.content

      ref_name
    end

    # ── Field Class Generation ────────────────────────────────────────

    def create_field_class(field_def)
      return unless field_def.name

      klass_name = "Field_#{field_def.name.gsub('-', '_')}"
      klass = Class.new(Lutaml::Model::Serializable)
      @classes[klass_name] = klass

      is_markup = TypeMapper.markup?(field_def.as_type)
      is_multiline = TypeMapper.multiline?(field_def.as_type)
      content_type = TypeMapper.map(field_def.as_type)

      if is_multiline
        apply_markup_multiline_attributes(klass)
      elsif is_markup
        apply_markup_attributes(klass)
      elsif field_def.collapsible == "yes"
        klass.attribute :content, content_type, collection: true
      else
        klass.attribute :content, content_type
      end

      field_def.define_flag&.each { |f| add_inline_flag(klass, f) }
      field_def.flag&.each { |f| add_flag_reference(klass, f) }

      build_field_xml(klass, field_def.name, is_markup || is_multiline,
                      field_def, is_multiline)
      build_field_json(klass, field_def)

      # Allow string-based deserialization: lutaml-model's of_json expects a
      # Hash, but fields can appear as plain strings in JSON (when no flags are
      # set, per NIST convention). Override of_json/from_json to handle both.
      has_flags = field_def.define_flag&.any? || field_def.flag&.any?
      has_json_vk = field_def.json_value_key || field_def.json_value_key_flag
      is_collapsible = field_def.collapsible == "yes"
      value_key = field_def.json_value_key || "STRVALUE"

      klass.define_singleton_method(:of_json) do |data|
        if data.is_a?(String)
          new(content: data)
        else
          super(data)
        end
      end

      klass.define_singleton_method(:from_json) do |data|
        if data.is_a?(String)
          new(content: data)
        else
          super(data)
        end
      end

      if has_flags || has_json_vk || is_collapsible
        flag_attr_names = (field_def.define_flag || []).filter_map do |f|
          safe_attr(f.name) if f.name
        end +
          (field_def.flag || []).filter_map do |f|
            safe_attr(f.ref) if f.ref
          end

        orig_as_json = klass.method(:as_json)
        klass.define_singleton_method(:as_json) do |instance, options = {}|
          result = orig_as_json.call(instance, options)

          # Collapsible: unwrap single-element content arrays
          if is_collapsible && result.is_a?(Hash) && result[value_key].is_a?(Array) && result[value_key].length == 1
            result[value_key] = result[value_key].first
          end

          # Fields with flags: when no flags are set, serialize as plain value
          if (has_flags || has_json_vk) && result.is_a?(Hash) && result.key?(value_key)
            flags_present = flag_attr_names.any? do |attr|
              val = instance.send(attr)
              val && !(val.respond_to?(:using_default?) && val.using_default?)
            end
            unless flags_present
              return result[value_key]
            end
          end

          result
        end
      end

      apply_constraint_validation(klass, field_def.constraint)
    end

    def apply_markup_attributes(klass)
      klass.attribute :content, :string, collection: true
      klass.attribute :a, AnchorType, collection: true
      klass.attribute :insert, InsertType, collection: true
      klass.attribute :br, :string, collection: true
      klass.attribute :code, CodeType, collection: true
      klass.attribute :em, InlineMarkupType, collection: true
      klass.attribute :i, InlineMarkupType, collection: true
      klass.attribute :b, InlineMarkupType, collection: true
      klass.attribute :strong, InlineMarkupType, collection: true
      klass.attribute :sub, InlineMarkupType, collection: true
      klass.attribute :sup, InlineMarkupType, collection: true
      klass.attribute :q, InlineMarkupType, collection: true
      klass.attribute :img, ImageType, collection: true
    end

    def apply_markup_multiline_attributes(klass)
      apply_markup_attributes(klass)
      klass.attribute :p, InlineMarkupType, collection: true
      klass.attribute :h1, InlineMarkupType, collection: true
      klass.attribute :h2, InlineMarkupType, collection: true
      klass.attribute :h3, InlineMarkupType, collection: true
      klass.attribute :h4, InlineMarkupType, collection: true
      klass.attribute :h5, InlineMarkupType, collection: true
      klass.attribute :h6, InlineMarkupType, collection: true
      klass.attribute :ul, ListType, collection: true
      klass.attribute :ol, OrderedListType, collection: true
      klass.attribute :pre, PreformattedType, collection: true
      klass.attribute :hr, :string, collection: true
      klass.attribute :blockquote, BlockQuoteType, collection: true
      klass.attribute :table, TableType, collection: true
    end

    def build_field_xml(klass, xml_element, is_markup, field_def,
is_multiline = false)
      flag_defs = field_def.define_flag || []
      flag_refs = field_def.flag || []

      # Precompute safe attribute names for XML mapping
      flag_attr_maps = flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      flag_ref_maps = flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      klass.class_eval do
        xml do
          element xml_element
          mixed_content if is_markup
          ordered if is_markup

          map_content to: :content

          if is_markup
            map_element "a", to: :a
            map_element "insert", to: :insert
            map_element "br", to: :br
            map_element "code", to: :code
            map_element "em", to: :em
            map_element "i", to: :i
            map_element "b", to: :b
            map_element "strong", to: :strong
            map_element "sub", to: :sub
            map_element "sup", to: :sup
            map_element "q", to: :q
            map_element "img", to: :img
          end

          if is_multiline
            map_element "p", to: :p
            map_element "h1", to: :h1
            map_element "h2", to: :h2
            map_element "h3", to: :h3
            map_element "h4", to: :h4
            map_element "h5", to: :h5
            map_element "h6", to: :h6
            map_element "ul", to: :ul
            map_element "ol", to: :ol
            map_element "pre", to: :pre
            map_element "hr", to: :hr
            map_element "blockquote", to: :blockquote
            map_element "table", to: :table
          end

          flag_attr_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end

          flag_ref_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end
        end
      end
    end

    # ── Key-Value Mapping Generation (JSON / YAML / TOML) ───────────
    # lutaml-model's key_value DSL generates mappings shared by all
    # key-value formats (JSON, YAML, TOML).  of_json / as_json / etc.
    # continue to work because they delegate to the same mappings.

    def build_field_json(klass, field_def)
      flag_defs = field_def.define_flag || []
      flag_refs = field_def.flag || []
      has_flags = flag_defs.any? || flag_refs.any?
      json_vk = field_def.json_value_key
      json_vk_flag = field_def.json_value_key_flag&.flag_ref

      if json_vk_flag
        build_field_json_value_key_flag(klass, field_def, json_vk_flag)
        return
      end

      value_key = json_vk || "STRVALUE"

      flag_attr_maps = flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      flag_ref_maps = flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      klass.class_eval do
        key_value do
          root field_def.name

          if has_flags || json_vk
            map value_key, to: :content
          else
            map "content", to: :content
          end

          flag_attr_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          flag_ref_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end
        end
      end
    end

    # json-value-key-flag: the flag value becomes the JSON key for content.
    # E.g. {"prop1": "value1", "id": "id1"} where "prop1" is the name flag value.
    # We store metadata on the field class and handle serialization via
    # custom with: callbacks at the assembly level.
    def build_field_json_value_key_flag(klass, field_def, key_flag_ref)
      key_attr = safe_attr(key_flag_ref)
      flag_defs = field_def.define_flag || []
      flag_refs = field_def.flag || []

      other_flag_maps = flag_defs.reject { |f| f.name == key_flag_ref }
        .filter_map do |f|
        if f.name
          [f.name,
           safe_attr(f.name)]
        end
      end +
        flag_refs.reject { |f| f.ref == key_flag_ref }
          .filter_map do |f|
          if f.ref
            [f.ref,
             safe_attr(f.ref)]
          end
        end

      # Store metadata: pairs of [json_key, attr_name] for other flags
      klass.instance_variable_set(:@json_vk_flag_key_attr, key_attr)
      klass.instance_variable_set(:@json_vk_flag_other_flag_maps,
                                  other_flag_maps)

      klass.class_eval do
        key_value do
          root field_def.name
          other_flag_maps.each do |json_name, attr_name|
            map json_name, to: attr_name
          end
        end
      end
    end

    # Build custom with: callbacks for a field that uses json-value-key-flag.
    # Called from build_assembly_json when the referenced field has this pattern.
    def build_vk_flag_field_callbacks(parent_klass, field_klass, json_name,
attr_sym)
      key_attr = field_klass.instance_variable_get(:@json_vk_flag_key_attr)
      other_flag_maps = field_klass.instance_variable_get(:@json_vk_flag_other_flag_maps)
      known_json_keys = other_flag_maps.map(&:first)

      from_method = :"json_from_vkf_#{attr_sym}_#{json_name.gsub('-', '_')}"
      to_method = :"json_to_vkf_#{attr_sym}_#{json_name.gsub('-', '_')}"

      parent_klass.define_method(from_method) do |instance, value|
        items = case value
                when Array then value
                when Hash then [value]
                when nil then []
                else [value]
                end
        parsed = items.map do |item|
          item = item.dup
          key_val = nil
          content_val = nil
          item.each do |k, v|
            unless known_json_keys.include?(k)
              key_val = k
              content_val = v
            end
          end
          obj = field_klass.allocate
          obj.instance_variable_set(:@using_default, {})
          obj.instance_variable_set(:@lutaml_register, :default)
          obj.instance_variable_set("@#{key_attr}", key_val)
          obj.instance_variable_set(:@content, content_val)
          other_flag_maps.each do |json_key, attr_name|
            if item.key?(json_key)
              obj.instance_variable_set("@#{attr_name}",
                                        item[json_key])
            end
          end
          obj
        end
        instance.instance_variable_set("@#{attr_sym}", parsed)
      end

      parent_klass.define_method(to_method) do |instance, doc|
        current = instance.instance_variable_get("@#{attr_sym}")
        if current.is_a?(Array)
          doc[json_name] = current.map do |item|
            key_val = item.instance_variable_get("@#{key_attr}")
            content_val = item.instance_variable_get(:@content)
            result = { key_val => content_val }
            other_flag_maps.each do |json_key, attr_name|
              val = item.instance_variable_get("@#{attr_name}")
              result[json_key] = val if val
            end
            result
          end
        end
      end

      { from_method: from_method, to_method: to_method }
    end

    # Build custom with: callbacks for BY_KEY group-as.
    # JSON format: {"key1": "val1", "key2": "val2"} — a map keyed by json-key flag.
    # Internal format: array of field instances, each with the key flag set.
    def build_by_key_field_callbacks(parent_klass, field_klass, json_name,
attr_sym, json_key_flag)
      key_attr = safe_attr(json_key_flag)
      field_klass && field_klass.instance_variable_get(:@json_vk_flag_key_attr).nil? &&
        field_klass.attributes.any? do |k, _|
          k != :content && k.to_s != key_attr.to_s
        end

      from_method = :"json_from_bykey_#{attr_sym}_#{json_name.gsub('-', '_')}"
      to_method = :"json_to_bykey_#{attr_sym}_#{json_name.gsub('-', '_')}"

      parent_klass.define_method(from_method) do |instance, value|
        return unless value.is_a?(Hash)

        parsed = value.map do |k, v|
          obj = if field_klass
                  field_klass.allocate.tap do |o|
                    o.instance_variable_set(:@using_default, {})
                    o.instance_variable_set(:@lutaml_register, :default)
                    o.instance_variable_set("@#{key_attr}", k)
                    if v.is_a?(Hash)
                      # Field with flags — deserialize from hash
                      v.each do |vk, vv|
                        attr_sym_local = vk.gsub("-", "_").to_sym
                        begin
                          o.instance_variable_set("@#{attr_sym_local}", vv)
                        rescue StandardError
                          # skip unknown attributes
                        end
                      end
                    else
                      o.instance_variable_set(:@content, v)
                    end
                  end
                else
                  k
                end
          obj
        end
        instance.instance_variable_set("@#{attr_sym}", parsed)
      end

      parent_klass.define_method(to_method) do |instance, doc|
        current = instance.instance_variable_get("@#{attr_sym}")
        if current.is_a?(Array)
          result = {}
          current.each do |item|
            if field_klass
              key_val = item.instance_variable_get("@#{key_attr}")
              content_val = item.instance_variable_get(:@content)
              if field_klass.attributes.keys.any? do |k|
                k != :content && k.to_s != key_attr.to_s && item.instance_variable_get("@#{k}")
              end
                # Has other flags — serialize as object
                obj = {}
                field_klass.attributes.each_key do |attr_k|
                  next if attr_k.to_s == key_attr.to_s

                  v = item.instance_variable_get("@#{attr_k}")
                  obj[attr_k.to_s] = v if v
                end
                result[key_val] = obj
              else
                result[key_val] = content_val
              end
            end
          end
          doc[json_name] = result
        end
      end

      { from_method: from_method, to_method: to_method }
    end

    # Handles BY_KEY group-as for assembly references.
    # In JSON, assemblies are keyed by their json-key flag value:
    #   {"en": {...}, "de": {...}}
    # On parse (from): deserialize each value into the assembly class,
    #   setting the key flag attribute on each instance.
    # On serialize (to): extract the key flag value and build a Hash.
    def build_by_key_assembly_callbacks(parent_klass, asm_klass, json_name,
attr_sym, json_key_flag, grouped: false, child_attr: nil)
      key_attr = safe_attr(json_key_flag)

      from_method = :"json_from_bykey_asm_#{attr_sym}_#{json_name.gsub('-',
                                                                       '_')}"
      to_method = :"json_to_bykey_asm_#{attr_sym}_#{json_name.gsub('-', '_')}"

      parent_klass.define_method(from_method) do |instance, value|
        return unless value.is_a?(Hash)

        parsed = value.map do |k, v|
          if asm_klass
            obj = if v.is_a?(Hash)
                    asm_klass.of_json(v)
                  else
                    asm_klass.new
                  end
            obj.instance_variable_set("@#{key_attr}", k)
            obj
          else
            k
          end
        end

        if grouped && child_attr
          # GROUPED wrapper: create wrapper instance containing the array
          wrapper = instance.instance_variable_get("@#{attr_sym}")
          unless wrapper
            attr_type = instance.class.attributes[attr_sym]
            wrapper = attr_type.type.new
          end
          wrapper.instance_variable_set("@#{child_attr}", parsed)
          instance.instance_variable_set("@#{attr_sym}", wrapper)
        else
          instance.instance_variable_set("@#{attr_sym}", parsed)
        end
      end

      parent_klass.define_method(to_method) do |instance, doc|
        current = instance.instance_variable_get("@#{attr_sym}")
        items = if grouped && current && child_attr
                  current.send(child_attr)
                else
                  current
                end

        if items.is_a?(Array)
          result = {}
          items.each do |item|
            next unless asm_klass

            key_val = item.instance_variable_get("@#{key_attr}")
            if item.is_a?(Lutaml::Model::Serializable)
              sub = asm_klass.as_json(item)
              # Remove the key flag from the sub-hash (it's the outer key)
              key_json_name = asm_klass.mappings_for(:json).instance_variable_get(:@mappings)
                .find do |_map_key, rule|
                rule.to.to_s == key_attr.to_s
              end&.first
              sub.delete(key_json_name) if key_json_name
              result[key_val] = sub.empty? ? {} : sub
            else
              result[key_val] = {}
            end
          end
          doc[json_name] = result
        end
      end

      { from_method: from_method, to_method: to_method }
    end

    def build_assembly_json(klass, root_name, assembly_def)
      flag_defs = assembly_def.define_flag || []
      flag_refs = assembly_def.flag || []

      flag_attr_maps = flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      flag_ref_maps = flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      json_field_mappings = collect_json_field_mappings(assembly_def)
      json_assembly_mappings = collect_json_assembly_mappings(assembly_def)

      # Separate vk_flag, by_key, and singleton_or_array mappings for custom handling
      vk_flag_mappings = json_field_mappings.select { |m| m[:vk_flag] }
      by_key_mappings = json_field_mappings.select { |m| m[:by_key] }
      soa_mappings = json_field_mappings.select { |m| m[:singleton_or_array] }
      regular_field_mappings = json_field_mappings.reject do |m|
        m[:vk_flag] || m[:by_key] || m[:singleton_or_array]
      end

      # Separate assembly SOA from regular assembly mappings
      assembly_by_key_mappings = json_assembly_mappings.select do |m|
        m[:by_key]
      end
      assembly_soa_mappings = json_assembly_mappings.select do |m|
        m[:singleton_or_array]
      end
      regular_assembly_mappings = json_assembly_mappings.reject do |m|
        m[:by_key] || m[:singleton_or_array]
      end

      klass.class_eval do
        key_value do
          root root_name

          flag_attr_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          flag_ref_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          regular_field_mappings.each do |mapping|
            if mapping[:scalar]
              map mapping[:json_name], to: mapping[:attr_name],
                                       with: { to: mapping[:to_method], from: mapping[:from_method] }
            else
              map mapping[:json_name], to: mapping[:attr_name],
                                       render_empty: true
            end
          end

          regular_assembly_mappings.each do |mapping|
            map mapping[:json_name], to: mapping[:attr_name], render_empty: true
          end
        end
      end

      # Define with: callback methods for scalar field mappings
      regular_field_mappings.each do |mapping|
        next unless mapping[:scalar]

        field_klass = mapping[:field_klass]
        attr_sym = mapping[:attr_name]

        has_flags = mapping[:has_flags]

        klass.define_method(mapping[:from_method]) do |instance, value|
          if value.is_a?(Array)
            parsed = value.map do |v|
              has_flags ? field_klass.of_json(v) : field_klass.new(content: v)
            end
            instance.instance_variable_set("@#{attr_sym}", parsed)
          elsif value.is_a?(Hash)
            if value.empty?
              inst = field_klass.new(content: "")
              inst.instance_variable_set(:@_was_empty_hash, true)
              instance.instance_variable_set("@#{attr_sym}", inst)
            else
              instance.instance_variable_set("@#{attr_sym}",
                                             field_klass.of_json(value))
            end
          elsif value
            instance.instance_variable_set("@#{attr_sym}",
                                           has_flags ? field_klass.of_json(value) : field_klass.new(content: value))
          end
        end

        klass.define_method(mapping[:to_method]) do |instance, doc|
          current = instance.instance_variable_get("@#{attr_sym}")
          if current.is_a?(Array)
            result = current.map do |item|
              if has_flags && item.is_a?(Lutaml::Model::Serializable)
                field_klass.as_json(item)
              else
                item.respond_to?(:content) ? item.content : item
              end
            end
            doc[mapping[:json_name]] = result
          elsif current
            if current.instance_variable_get(:@_was_empty_hash)
              doc[mapping[:json_name]] = {}
            elsif has_flags && current.is_a?(Lutaml::Model::Serializable)
              doc[mapping[:json_name]] = field_klass.as_json(current)
            else
              val = current.respond_to?(:content) ? current.content : current
              doc[mapping[:json_name]] = val
            end
          end
        end
      end

      # Handle SINGLETON_OR_ARRAY non-scalar field mappings with custom with: callbacks
      soa_mappings.each do |mapping|
        attr_sym = mapping[:attr_name]
        json_name = mapping[:json_name]
        from_m = mapping[:from_method]
        to_m = mapping[:to_method]
        field_klass = mapping[:field_klass]

        klass.define_method(from_m) do |instance, value|
          items = case value
                  when Hash then [value]
                  when Array then value
                  when String then [value]
                  else return
                  end
          parsed = items.map do |item|
            case item
            when Hash then field_klass.of_json(item)
            when String then field_klass.of_json(item)
            else item
            end
          end
          instance.instance_variable_set("@#{attr_sym}", parsed)
        end

        klass.define_method(to_m) do |instance, doc|
          current = instance.instance_variable_get("@#{attr_sym}")
          if current.is_a?(Array)
            result = current.map do |item|
              if item.is_a?(Lutaml::Model::Serializable)
                field_klass.as_json(item)
              else
                item
              end
            end
            doc[json_name] = result.length == 1 ? result.first : result
          end
        end

        klass.class_eval do
          key_value do
            map json_name, to: attr_sym,
                           with: { to: to_m, from: from_m }
          end
        end

        # Add alias mapping for ref name if it differs from group-as name
        if mapping[:alt_json_name]
          klass.class_eval do
            key_value do
              map mapping[:alt_json_name], to: attr_sym,
                                           with: { to: to_m, from: from_m }
            end
          end
        end
      end

      # Handle json-value-key-flag fields with custom with: callbacks
      vk_flag_mappings.each do |mapping|
        callbacks = build_vk_flag_field_callbacks(
          klass, mapping[:field_klass], mapping[:json_name], mapping[:attr_name]
        )
        # Re-open json block to add the mapping with custom with:
        klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      # Handle BY_KEY group-as with custom with: callbacks
      by_key_mappings.each do |mapping|
        # Ensure the mapping target attribute exists (GROUPED wrappers may not
        # register the child attr name as a top-level attribute)
        unless klass.attributes.key?(mapping[:attr_name])
          klass.attribute mapping[:attr_name], mapping[:field_klass],
                          collection: true
        end
        callbacks = build_by_key_field_callbacks(
          klass, mapping[:field_klass], mapping[:json_name],
          mapping[:attr_name], mapping[:json_key_flag]
        )
        klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      # Handle BY_KEY assembly mappings with custom with: callbacks
      assembly_by_key_mappings.each do |mapping|
        unless klass.attributes.key?(mapping[:attr_name])
          asm_type = mapping[:asm_klass] || Lutaml::Model::Serializable
          klass.attribute mapping[:attr_name], asm_type, collection: true
        end
        callbacks = build_by_key_assembly_callbacks(
          klass, mapping[:asm_klass], mapping[:json_name],
          mapping[:attr_name], mapping[:json_key_flag],
          grouped: mapping[:grouped] || false,
          child_attr: mapping[:child_attr]
        )
        klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      # Handle SINGLETON_OR_ARRAY assembly mappings with custom with: callbacks
      assembly_soa_mappings.each do |mapping|
        attr_sym = mapping[:attr_name]
        json_name = mapping[:json_name]
        from_m = mapping[:from_method]
        to_m = mapping[:to_method]
        asm_klass = mapping[:asm_klass]

        # Typed instances for all SOA (both explicit and implicit)
        klass.define_method(from_m) do |instance, value|
          items = case value
                  when Hash then [value]
                  when Array then value
                  else return
                  end
          parsed = if asm_klass
                     items.map do |item|
                       asm_klass.of_json(item.is_a?(Hash) ? item : {})
                     end
                   else
                     items
                   end
          # For singleton attributes (collection: false), unwrap single-item arrays
          attr_def = klass.attributes[attr_sym]
          if parsed.length == 1 && attr_def && !attr_def.collection
            instance.instance_variable_set("@#{attr_sym}", parsed.first)
          else
            instance.instance_variable_set("@#{attr_sym}", parsed)
          end
        end

        klass.define_method(to_m) do |instance, doc|
          current = instance.instance_variable_get("@#{attr_sym}")
          if current.is_a?(Array)
            result = current.map do |item|
              if asm_klass && item.is_a?(Lutaml::Model::Serializable)
                asm_klass.as_json(item)
              else
                item
              end
            end
            doc[json_name] = result.length == 1 ? result.first : result
          elsif current
            doc[json_name] = if asm_klass && current.is_a?(Lutaml::Model::Serializable)
                               asm_klass.as_json(current)
                             else
                               current
                             end
          end
        end

        klass.class_eval do
          key_value do
            map json_name, to: attr_sym, render_empty: true,
                           with: { to: to_m, from: from_m }
          end
        end
      end

      # Collapsible BY_KEY: when an assembly has no flags and only one BY_KEY
      # child, the NIST toolchain outputs the BY_KEY map directly without the
      # group-as name wrapper (e.g. author-index JSON is {"archimedes": {...}}
      # not {"authors": {"archimedes": {...}}}).
      if flag_defs.empty? && flag_refs.empty? &&
          json_assembly_mappings.length == 1 &&
          json_assembly_mappings.first[:by_key]

        by_key_json_name = json_assembly_mappings.first[:json_name]

        orig_of_json = klass.method(:of_json)
        klass.define_singleton_method(:of_json) do |data, options = {}|
          if data.is_a?(Hash) && !data.key?(by_key_json_name)
            orig_of_json.call({ by_key_json_name => data }, options)
          else
            orig_of_json.call(data, options)
          end
        end

        orig_as_json = klass.method(:as_json)
        klass.define_singleton_method(:as_json) do |instance, options = {}|
          result = orig_as_json.call(instance, options)
          if result.is_a?(Hash) && result.key?(by_key_json_name)
            result[by_key_json_name]
          else
            result
          end
        end
      end
    end

    def collect_json_field_mappings(assembly_def)
      mappings = []
      model = assembly_def.model
      return mappings unless model

      mappings.concat(collect_model_json_field_mappings(model))
      mappings
    end

    def collect_model_json_field_mappings(model)
      mappings = []

      model.field&.each { |fr| mappings << build_field_json_mapping(fr) }
      model.define_field&.each do |fd|
        mappings << build_inline_field_json_mapping(fd) if fd.name
      end
      model.choice&.each do |c|
        c.field&.each { |fr| mappings << build_field_json_mapping(fr) }
        c.define_field&.each do |fd|
          mappings << build_inline_field_json_mapping(fd) if fd.name
        end
      end
      model.choice_group&.each do |cg|
        cg.field&.each do |fr|
          mappings << build_field_json_mapping(fr, cg.group_as)
        end
        cg.define_field&.each do |fd|
          mappings << build_inline_field_json_mapping(fd) if fd.name
        end
      end

      mappings
    end

    def build_field_json_mapping(field_ref, override_group_as = nil)
      ref_name = field_ref.ref
      return nil unless ref_name

      group_as = override_group_as || field_ref.group_as
      field_def = @field_defs[ref_name]
      field_klass = @classes["Field_#{ref_name.gsub('-', '_')}"]
      has_flags = field_has_flags?(field_def)

      json_name = if group_as
                    group_as.name
                  else
                    field_ref.use_name&.content || ref_name
                  end
      attr_name = safe_attr(ref_name)

      # Check for BY_KEY group-as
      if group_as&.in_json == "BY_KEY"
        json_key_flag = field_def&.json_key&.flag_ref
        return {
          json_name: json_name, attr_name: attr_name,
          by_key: true, field_klass: field_klass,
          json_key_flag: json_key_flag
        }
      end

      # Check for json-value-key-flag pattern
      if field_klass&.instance_variable_get(:@json_vk_flag_key_attr)
        return {
          json_name: json_name, attr_name: attr_name,
          vk_flag: true, field_klass: field_klass
        }
      end

      if has_flags
        is_soa = group_as && ["SINGLETON_OR_ARRAY",
                              "ARRAY"].include?(group_as.in_json)
        method_suffix = "#{attr_name}_#{json_name.gsub('-', '_')}"
        if is_soa
          result = {
            json_name: json_name, attr_name: attr_name, scalar: false,
            singleton_or_array: true, field_klass: field_klass,
            to_method: :"json_soa_to_#{method_suffix}",
            from_method: :"json_soa_from_#{method_suffix}"
          }
          # Include ref_name for SOA fields with group-as, so we can also
          # accept the ref name as a JSON key during deserialization (some
          # NIST worked examples use ref name instead of group-as name).
          if group_as && ref_name != json_name
            result[:alt_json_name] =
              ref_name
          end
          result
        else
          # Singleton field with flags: typed instance, no array wrapping
          {
            json_name: json_name, attr_name: attr_name, scalar: true,
            has_flags: true, field_klass: field_klass,
            to_method: :"json_to_#{method_suffix}",
            from_method: :"json_from_#{method_suffix}"
          }
        end
      else
        method_suffix = "#{attr_name}_#{json_name.gsub('-', '_')}"
        {
          json_name: json_name, attr_name: attr_name, scalar: true,
          field_klass: field_klass,
          to_method: :"json_to_#{method_suffix}",
          from_method: :"json_from_#{method_suffix}"
        }
      end
    end

    def build_inline_field_json_mapping(field_def)
      json_name = field_def.name
      attr_name = safe_attr(field_def.name)
      has_flags = field_has_flags?(field_def)

      if has_flags
        field_klass = @classes[scoped_field_name(field_def.name)]
        method_suffix = "#{attr_name}_#{json_name.gsub('-', '_')}"
        {
          json_name: json_name, attr_name: attr_name, scalar: false,
          singleton_or_array: true, field_klass: field_klass,
          to_method: :"json_soa_to_#{method_suffix}",
          from_method: :"json_soa_from_#{method_suffix}"
        }
      else
        { json_name: json_name, attr_name: attr_name, scalar: false }
      end
    end

    def field_has_flags?(field_def, _field_ref = nil)
      return false unless field_def

      field_def.define_flag&.any? || field_def.flag&.any? || field_def.json_value_key || field_def.json_value_key_flag
    end

    def collect_json_assembly_mappings(assembly_def)
      mappings = []
      model = assembly_def.model
      return mappings unless model

      mappings.concat(collect_model_json_assembly_mappings(model))
      mappings
    end

    def collect_model_json_assembly_mappings(model)
      mappings = []

      model.assembly&.each do |ar|
        ref_name = ar.ref
        next unless ref_name

        group_as = ar.group_as
        json_name = group_as&.name || ar.use_name&.content || ref_name
        # When GROUPED in XML, the attribute is the group-as name (wrapper).
        # Otherwise it's the ref name (direct collection).
        attr_name = group_as&.in_xml == "GROUPED" ? safe_attr(group_as.name) : safe_attr(ref_name)
        mapping = { json_name: json_name, attr_name: attr_name }
        if group_as&.in_json == "BY_KEY"
          asm_def = @assembly_defs[ref_name]
          json_key_flag = asm_def&.json_key&.flag_ref
          asm_klass = @classes["Assembly_#{ref_name.gsub('-', '_')}"]
          mapping[:by_key] = true
          mapping[:asm_klass] = asm_klass
          mapping[:json_key_flag] = json_key_flag
          mapping[:grouped] = true if group_as&.in_xml == "GROUPED"
          if group_as&.in_xml == "GROUPED"
            mapping[:child_attr] =
              safe_attr(ref_name)
          end
        else
          check_assembly_soa(mapping, group_as, attr_name, json_name)
        end
        mappings << mapping
      end

      model.define_assembly&.each do |ad|
        next unless ad.name

        group_as = ad.group_as
        json_name = group_as&.name || ad.name
        attr_name = safe_attr(ad.name)
        mapping = { json_name: json_name, attr_name: attr_name }
        if group_as&.in_json == "BY_KEY"
          json_key_flag = ad.json_key&.flag_ref
          mapping[:by_key] = true
          mapping[:json_key_flag] = json_key_flag
        else
          check_assembly_soa(mapping, group_as, attr_name, json_name)
        end
        mappings << mapping
      end

      model.choice&.each do |c|
        c.assembly&.each do |ar|
          ref_name = ar.ref
          next unless ref_name

          group_as = ar.group_as
          json_name = group_as&.name || ar.use_name&.content || ref_name
          attr_name = safe_attr(ref_name)
          mapping = { json_name: json_name, attr_name: attr_name }
          check_assembly_soa(mapping, group_as, attr_name, json_name)
          mappings << mapping
        end
        c.define_assembly&.each do |ad|
          next unless ad.name

          group_as = ad.group_as
          json_name = group_as&.name || ad.name
          attr_name = safe_attr(ad.name)
          mapping = { json_name: json_name, attr_name: attr_name }
          check_assembly_soa(mapping, group_as, attr_name, json_name)
          mappings << mapping
        end
      end

      model.choice_group&.each do |cg|
        group_as = cg.group_as
        json_name = group_as&.name
        cg.assembly&.each do |ar|
          ref_name = ar.ref
          next unless ref_name

          name = json_name || ar.use_name&.content || ref_name
          attr_name = safe_attr(ref_name)
          mapping = { json_name: name, attr_name: attr_name }
          check_assembly_soa(mapping, group_as, attr_name, name)
          mappings << mapping
        end
        cg.define_assembly&.each do |ad|
          next unless ad.name

          name = json_name || ad.name
          attr_name = safe_attr(ad.name)
          mapping = { json_name: name, attr_name: attr_name }
          check_assembly_soa(mapping, group_as, attr_name, name)
          mappings << mapping
        end
      end

      mappings
    end

    def check_assembly_soa(mapping, group_as, attr_name, json_name)
      is_soa = group_as&.in_json == "SINGLETON_OR_ARRAY" || group_as.nil?
      return unless is_soa

      method_suffix = "#{attr_name}_#{json_name.gsub('-', '_')}"
      mapping[:singleton_or_array] = true
      mapping[:to_method] = :"json_assembly_soa_to_#{method_suffix}"
      mapping[:from_method] = :"json_assembly_soa_from_#{method_suffix}"
      # Attach the assembly class for casting in from: callback
      asm_klass = @classes["Assembly_#{attr_name.to_s.gsub('-', '_')}"]
      mapping[:asm_klass] = asm_klass if asm_klass
    end

    # ── Assembly Class Generation ─────────────────────────────────────

    def create_assembly_placeholder(assembly_def)
      return unless assembly_def.name

      klass_name = "Assembly_#{assembly_def.name.gsub('-', '_')}"
      @classes[klass_name] ||= Class.new(Lutaml::Model::Serializable)
    end

    def populate_assembly_class(assembly_def)
      return unless assembly_def.name

      klass_name = "Assembly_#{assembly_def.name.gsub('-', '_')}"
      klass = @classes[klass_name]
      return unless klass

      @current_assembly_name = assembly_def.name.gsub("-", "_")

      assembly_def.define_flag&.each { |f| add_inline_flag(klass, f) }
      assembly_def.flag&.each { |f| add_flag_reference(klass, f) }

      process_model(klass, assembly_def.model) if assembly_def.model

      root_name = assembly_def.root_name&.content || assembly_def.name
      build_assembly_xml(klass, root_name, assembly_def)
      build_assembly_json(klass, root_name, assembly_def)

      if assembly_def.root_name&.content
        add_json_root_handling(klass,
                               root_name)
      end

      apply_constraint_validation(klass, assembly_def.constraint)
      klass.instance_variable_set(:@populated, true)
    ensure
      @current_assembly_name = nil
    end

    def build_assembly_xml(klass, root_name, assembly_def)
      flag_defs = assembly_def.define_flag || []
      flag_refs = assembly_def.flag || []
      child_mappings = collect_child_mappings(assembly_def)

      # Precompute safe attribute names
      flag_attr_maps = flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      flag_ref_maps = flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      klass.class_eval do
        xml do
          element root_name
          ordered

          flag_attr_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end

          flag_ref_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end

          child_mappings.each do |mapping|
            map_element mapping[:xml_name], to: mapping[:attr_name]
          end
        end
      end
    end

    def collect_child_mappings(assembly_def)
      mappings = []
      model = assembly_def.model
      return mappings unless model

      mappings.concat(collect_model_child_mappings(model))
      mappings
    end

    def collect_model_child_mappings(model)
      mappings = []

      model.field&.each do |field_ref|
        ref_name = field_ref.ref
        next unless ref_name

        xml_name = field_ref.use_name&.content || ref_name
        group_as = field_ref.group_as
        grouped = group_as&.in_xml == "GROUPED"

        mappings << build_child_mapping(xml_name, group_as, grouped, ref_name)
      end

      model.assembly&.each do |assembly_ref|
        ref_name = assembly_ref.ref
        next unless ref_name

        xml_name = assembly_xml_element_name(assembly_ref)
        group_as = assembly_ref.group_as
        grouped = group_as&.in_xml == "GROUPED"

        attr_name = grouped ? safe_attr(group_as.name) : safe_attr(ref_name)
        mappings << { xml_name: grouped ? group_as.name : xml_name,
                      attr_name: attr_name, grouped: grouped }
      end

      model.define_field&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      model.define_assembly&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      model.choice&.each do |c|
        mappings.concat(collect_choice_child_mappings(c))
      end
      model.choice_group&.each do |cg|
        mappings.concat(collect_choice_group_child_mappings(cg))
      end

      mappings
    end

    def collect_choice_child_mappings(choice)
      mappings = []

      choice.field&.each do |field_ref|
        ref_name = field_ref.ref
        next unless ref_name

        xml_name = field_ref.use_name&.content || ref_name
        group_as = field_ref.group_as
        grouped = group_as&.in_xml == "GROUPED"

        mappings << build_child_mapping(xml_name, group_as, grouped, ref_name)
      end

      choice.assembly&.each do |assembly_ref|
        ref_name = assembly_ref.ref
        next unless ref_name

        xml_name = assembly_xml_element_name(assembly_ref)
        group_as = assembly_ref.group_as
        grouped = group_as&.in_xml == "GROUPED"

        attr_name = grouped ? safe_attr(group_as.name) : safe_attr(ref_name)
        mappings << { xml_name: grouped ? group_as.name : xml_name,
                      attr_name: attr_name, grouped: grouped }
      end

      choice.define_field&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      choice.define_assembly&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      mappings
    end

    def collect_choice_group_child_mappings(choice_group)
      mappings = []

      choice_group.field&.each do |field_ref|
        ref_name = field_ref.ref
        next unless ref_name

        xml_name = field_ref.use_name&.content || ref_name
        group_as = choice_group.group_as
        grouped = group_as&.in_xml == "GROUPED"
        mappings << build_child_mapping(xml_name, group_as, grouped, ref_name)
      end

      choice_group.assembly&.each do |assembly_ref|
        ref_name = assembly_ref.ref
        next unless ref_name

        xml_name = assembly_xml_element_name(assembly_ref)
        group_as = choice_group.group_as
        grouped = group_as&.in_xml == "GROUPED"
        attr_name = grouped ? safe_attr(group_as.name) : safe_attr(ref_name)
        mappings << { xml_name: grouped ? group_as.name : xml_name,
                      attr_name: attr_name, grouped: grouped }
      end

      choice_group.define_field&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      choice_group.define_assembly&.each do |inline_def|
        next unless inline_def.name

        mappings << { xml_name: inline_def.name,
                      attr_name: safe_attr(inline_def.name), grouped: false }
      end

      mappings
    end

    def build_child_mapping(xml_name, group_as, grouped, ref_name = nil)
      if grouped
        { xml_name: group_as.name, attr_name: safe_attr(group_as.name),
          grouped: true }
      else
        attr_name = safe_attr(ref_name || xml_name)
        { xml_name: xml_name, attr_name: attr_name, grouped: false }
      end
    end

    # ── Model Processing ──────────────────────────────────────────────

    def process_model(klass, model)
      # Initialize occurrence constraints registry
      unless klass.instance_variable_defined?(:@occurrence_constraints)
        klass.instance_variable_set(:@occurrence_constraints,
                                    {})
      end
      occ = klass.instance_variable_get(:@occurrence_constraints)

      model.field&.each do |fr|
        add_field_reference(klass, fr)
        record_occurrence_constraint(occ, fr)
      end
      model.assembly&.each do |ar|
        add_assembly_reference(klass, ar)
        record_occurrence_constraint(occ, ar)
      end
      model.define_field&.each { |fd| add_inline_field(klass, fd) }
      model.define_assembly&.each { |ad| add_inline_assembly(klass, ad) }
      model.choice&.each { |c| process_choice(klass, c) }
      model.choice_group&.each { |cg| process_choice_group(klass, cg) }
      add_any_content(klass) if model.any

      # Add validate_occurrences method if not already defined
      unless klass.method_defined?(:validate_occurrences)
        occ_ref = klass.instance_variable_get(:@occurrence_constraints)
        klass.define_method(:validate_occurrences) do
          Metaschema::ConstraintValidator.validate_occurrences(self, occ_ref)
        end
      end
    end

    def record_occurrence_constraint(occ, ref)
      ref_name = ref.ref
      return unless ref_name

      attr_name = safe_attr(ref_name)
      min = ref.min_occurs.to_i
      max_raw = ref.max_occurs
      max = max_raw == "unbounded" ? nil : max_raw&.to_i

      occ[attr_name] = { min: min, max: max } if min.positive? || max
    end

    def add_field_reference(klass, field_ref)
      ref_name = field_ref.ref
      return unless ref_name

      field_klass = @classes["Field_#{ref_name.gsub('-', '_')}"]
      return unless field_klass

      collection = unbounded?(field_ref.max_occurs)
      group_as = field_ref.group_as

      if group_as&.in_xml == "GROUPED"
        group_attr = safe_attr(group_as.name)
        wrapper_klass = Class.new(Lutaml::Model::Serializable)
        child_attr = safe_attr(ref_name)
        wrapper_klass.attribute child_attr, field_klass, collection: true
        wrapper_klass.class_eval do
          xml do
            element group_as.name
            map_element ref_name, to: child_attr
          end
        end
        klass.attribute group_attr, wrapper_klass
      else
        attr_name = safe_attr(ref_name)
        klass.attribute attr_name, field_klass, collection: collection
      end
    end

    def add_assembly_reference(klass, assembly_ref)
      ref_name = assembly_ref.ref
      return unless ref_name

      assembly_klass = @classes["Assembly_#{ref_name.gsub('-', '_')}"] ||
        create_placeholder_assembly(ref_name)

      collection = unbounded?(assembly_ref.max_occurs)
      group_as = assembly_ref.group_as
      xml_name = assembly_xml_element_name(assembly_ref)

      if group_as&.in_xml == "GROUPED"
        group_attr = safe_attr(group_as.name)
        child_attr = safe_attr(ref_name)
        wrapper_klass = Class.new(Lutaml::Model::Serializable)
        wrapper_klass.attribute child_attr, assembly_klass, collection: true
        wrapper_klass.class_eval do
          xml do
            element group_as.name
            map_element xml_name, to: child_attr
          end
        end
        klass.attribute group_attr, wrapper_klass
      else
        attr_name = safe_attr(ref_name)
        klass.attribute attr_name, assembly_klass, collection: collection
      end
    end

    def add_inline_field(klass, field_def)
      return unless field_def.name

      attr_name = safe_attr(field_def.name)
      is_markup = TypeMapper.markup?(field_def.as_type)
      is_multiline = TypeMapper.multiline?(field_def.as_type)
      content_type = TypeMapper.map(field_def.as_type)
      collection = unbounded?(field_def.max_occurs)
      has_flags = field_def.define_flag&.any? || field_def.flag&.any?

      if is_markup || is_multiline
        inline_klass = Class.new(Lutaml::Model::Serializable)
        if is_multiline
          apply_markup_multiline_attributes(inline_klass)
        else
          apply_markup_attributes(inline_klass)
        end

        field_def.define_flag&.each { |f| add_inline_flag(inline_klass, f) }
        field_def.flag&.each { |f| add_flag_reference(inline_klass, f) }

        inline_name = field_def.name
        inline_flag_defs = field_def.define_flag || []
        inline_flag_refs = field_def.flag || []
        inline_flag_attr_maps = inline_flag_defs.filter_map do |f|
          [f.name, safe_attr(f.name)] if f.name
        end
        inline_flag_ref_maps = inline_flag_refs.filter_map do |f|
          [f.ref, safe_attr(f.ref)] if f.ref
        end

        inline_klass.class_eval do
          xml do
            element inline_name
            mixed_content
            ordered
            map_content to: :content
            map_element "a", to: :a
            map_element "insert", to: :insert
            map_element "br", to: :br
            map_element "code", to: :code
            map_element "em", to: :em
            map_element "i", to: :i
            map_element "b", to: :b
            map_element "strong", to: :strong
            map_element "sub", to: :sub
            map_element "sup", to: :sup
            map_element "q", to: :q
            map_element "img", to: :img

            if is_multiline
              map_element "p", to: :p
              map_element "h1", to: :h1
              map_element "h2", to: :h2
              map_element "h3", to: :h3
              map_element "h4", to: :h4
              map_element "h5", to: :h5
              map_element "h6", to: :h6
              map_element "ul", to: :ul
              map_element "ol", to: :ol
              map_element "pre", to: :pre
              map_element "hr", to: :hr
              map_element "blockquote", to: :blockquote
              map_element "table", to: :table
            end

            inline_flag_attr_maps.each do |xml_name, attr_name|
              map_attribute xml_name, to: attr_name
            end

            inline_flag_ref_maps.each do |xml_name, attr_name|
              map_attribute xml_name, to: attr_name
            end
          end
        end

        klass.attribute attr_name, inline_klass, collection: collection
      elsif has_flags
        # Non-markup field with flags needs its own class for flag attributes
        inline_klass = Class.new(Lutaml::Model::Serializable)
        inline_klass.attribute :content, content_type
        field_def.define_flag&.each { |f| add_inline_flag(inline_klass, f) }
        field_def.flag&.each { |f| add_flag_reference(inline_klass, f) }

        flag_attr_maps = field_def.define_flag&.filter_map do |f|
          [f.name, safe_attr(f.name)] if f.name
        end || []
        flag_ref_maps = field_def.flag&.filter_map do |f|
          [f.ref, safe_attr(f.ref)] if f.ref
        end || []

        inline_name = field_def.name
        inline_klass.class_eval do
          xml do
            element inline_name
            map_content to: :content
            flag_attr_maps.each do |xml_name, attr_sym|
              map_attribute xml_name, to: attr_sym
            end
            flag_ref_maps.each do |xml_name, attr_sym|
              map_attribute xml_name, to: attr_sym
            end
          end
          key_value do
            root inline_name
            map "STRVALUE", to: :content
            flag_attr_maps.each do |xml_name, attr_sym|
              map xml_name, to: attr_sym
            end
            flag_ref_maps.each do |xml_name, attr_sym|
              map xml_name, to: attr_sym
            end
          end
        end

        # Register inline field class for JSON mapping lookups (scoped to parent)
        klass_name = scoped_field_name(field_def.name)
        @classes[klass_name] = inline_klass

        klass.attribute attr_name, inline_klass, collection: collection
      else
        klass.attribute attr_name, content_type, collection: collection
      end
    end

    def add_inline_assembly(klass, assembly_def)
      return unless assembly_def.name

      attr_name = safe_attr(assembly_def.name)
      collection = unbounded?(assembly_def.max_occurs)

      inline_klass = Class.new(Lutaml::Model::Serializable)

      assembly_def.define_flag&.each { |f| add_inline_flag(inline_klass, f) }
      assembly_def.flag&.each { |f| add_flag_reference(inline_klass, f) }

      process_model(inline_klass, assembly_def.model) if assembly_def.model

      inline_name = assembly_def.name
      inline_flag_defs = assembly_def.define_flag || []
      inline_flag_refs = assembly_def.flag || []
      inline_child_mappings = assembly_def.model ? collect_inline_child_mappings(assembly_def) : []
      inline_flag_attr_maps = inline_flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      inline_flag_ref_maps = inline_flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      inline_klass.class_eval do
        xml do
          element inline_name
          ordered

          inline_flag_attr_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end

          inline_flag_ref_maps.each do |xml_name, attr_name|
            map_attribute xml_name, to: attr_name
          end

          inline_child_mappings.each do |mapping|
            map_element mapping[:xml_name], to: mapping[:attr_name]
          end
        end
      end

      klass.attribute attr_name, inline_klass, collection: collection

      # Add JSON mappings for the inline assembly
      build_inline_assembly_json(klass, inline_klass, inline_name, assembly_def)
    end

    def build_inline_assembly_json(_parent_klass, inline_klass, inline_name,
assembly_def)
      flag_defs = assembly_def.define_flag || []
      flag_refs = assembly_def.flag || []

      inline_flag_attr_maps = flag_defs.filter_map do |f|
        [f.name, safe_attr(f.name)] if f.name
      end
      inline_flag_ref_maps = flag_refs.filter_map do |f|
        [f.ref, safe_attr(f.ref)] if f.ref
      end

      json_field_mappings = collect_json_field_mappings(assembly_def)
      json_assembly_mappings = collect_json_assembly_mappings(assembly_def)

      # Check if this inline assembly has any nested assembly children
      # that might be empty objects (choice assemblies). If so, we need
      # custom JSON handling because lutaml-model skips empty nested models.
      has_nested_asm = json_assembly_mappings.any?

      if has_nested_asm
        # Use custom of_json/to_json that handles empty nested assemblies
        build_inline_assembly_json_custom(
          inline_klass, inline_name, inline_flag_attr_maps, inline_flag_ref_maps,
          json_field_mappings, json_assembly_mappings
        )
      else
        # Standard lutaml-model mapping approach
        build_inline_assembly_json_standard(
          inline_klass, inline_name, inline_flag_attr_maps, inline_flag_ref_maps,
          json_field_mappings
        )
      end
    end

    def build_inline_assembly_json_standard(inline_klass, inline_name,
                                             inline_flag_attr_maps, inline_flag_ref_maps,
                                             json_field_mappings)
      regular_field_mappings = json_field_mappings.reject do |m|
        m[:vk_flag] || m[:by_key]
      end
      vk_flag_mappings = json_field_mappings.select { |m| m[:vk_flag] }
      by_key_mappings = json_field_mappings.select { |m| m[:by_key] }

      inline_klass.class_eval do
        key_value do
          root inline_name

          inline_flag_attr_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          inline_flag_ref_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          regular_field_mappings.each do |mapping|
            if mapping[:scalar]
              map mapping[:json_name], to: mapping[:attr_name],
                                       with: { to: mapping[:to_method], from: mapping[:from_method] }
            else
              map mapping[:json_name], to: mapping[:attr_name],
                                       render_empty: true
            end
          end
        end
      end

      define_scalar_field_callbacks(inline_klass, regular_field_mappings)

      vk_flag_mappings.each do |mapping|
        callbacks = build_vk_flag_field_callbacks(
          inline_klass, mapping[:field_klass], mapping[:json_name], mapping[:attr_name]
        )
        inline_klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      by_key_mappings.each do |mapping|
        callbacks = build_by_key_field_callbacks(
          inline_klass, mapping[:field_klass], mapping[:json_name],
          mapping[:attr_name], mapping[:json_key_flag]
        )
        inline_klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end
    end

    def build_inline_assembly_json_custom(inline_klass, inline_name,
                                           inline_flag_attr_maps, inline_flag_ref_maps,
                                           json_field_mappings, json_assembly_mappings)
      # Build full JSON mappings — include assembly mappings so lutaml-model's
      # Transformation path can parse them when this class is nested in a parent.
      regular_field_mappings = json_field_mappings.reject do |m|
        m[:vk_flag] || m[:by_key]
      end
      vk_flag_mappings = json_field_mappings.select { |m| m[:vk_flag] }
      by_key_mappings = json_field_mappings.select { |m| m[:by_key] }

      # Pre-generate method names for assembly mappings (only to: for serialization)
      json_assembly_mappings.each do |mapping|
        json_name = mapping[:json_name]
        attr_sym = mapping[:attr_name]
        mapping[:to_method] =
          :"json_to_asm_#{attr_sym}_#{json_name.gsub('-', '_')}"
      end

      inline_klass.class_eval do
        key_value do
          root inline_name

          inline_flag_attr_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          inline_flag_ref_maps.each do |xml_name, attr_name|
            map xml_name, to: attr_name
          end

          regular_field_mappings.each do |mapping|
            if mapping[:scalar]
              map mapping[:json_name], to: mapping[:attr_name],
                                       with: { to: mapping[:to_method], from: mapping[:from_method] }
            else
              map mapping[:json_name], to: mapping[:attr_name],
                                       render_empty: true
            end
          end

          # Assembly mappings use to: override for serialization.
          # Default from: handles casting via lutaml-model's built-in mechanism.
          json_assembly_mappings.each do |mapping|
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: mapping[:to_method] }
          end
        end
      end

      # Define with: callback methods for scalar field mappings
      define_scalar_field_callbacks(inline_klass, regular_field_mappings)

      vk_flag_mappings.each do |mapping|
        callbacks = build_vk_flag_field_callbacks(
          inline_klass, mapping[:field_klass], mapping[:json_name], mapping[:attr_name]
        )
        inline_klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      by_key_mappings.each do |mapping|
        callbacks = build_by_key_field_callbacks(
          inline_klass, mapping[:field_klass], mapping[:json_name],
          mapping[:attr_name], mapping[:json_key_flag]
        )
        inline_klass.class_eval do
          key_value do
            map mapping[:json_name], to: mapping[:attr_name],
                                     with: { to: callbacks[:to_method], from: callbacks[:from_method] }
          end
        end
      end

      # Define to: callback methods for assembly mappings.
      json_assembly_mappings.each do |mapping|
        attr_sym = mapping[:attr_name]
        to_method = mapping[:to_method]
        json_name = mapping[:json_name]

        inline_klass.define_method(to_method) do |instance, doc|
          current = instance.instance_variable_get("@#{attr_sym}")
          if current
            if current.is_a?(Lutaml::Model::Serializable)
              # Serialize the nested assembly's attributes into the doc
              sub = {}
              current.class.mappings_for(:json).instance_variable_get(:@mappings).each do |key, rule|
                val = current.send(rule.to)
                next if val.nil?

                sub[key] = val.respond_to?(:content) ? val.content : val
              end
              doc[json_name] = sub.empty? ? {} : sub
            else
              doc[json_name] = current
            end
          end
        end
      end
    end

    def define_scalar_field_callbacks(klass, field_mappings)
      field_mappings.each do |mapping|
        next unless mapping[:scalar]

        field_klass = mapping[:field_klass]
        attr_sym = mapping[:attr_name]

        klass.define_method(mapping[:from_method]) do |instance, value|
          if value.is_a?(Array)
            instance.instance_variable_set("@#{attr_sym}", value.map do |v|
              field_klass.new(content: v)
            end)
          elsif value
            instance.instance_variable_set("@#{attr_sym}",
                                           field_klass.new(content: value))
          end
        end

        klass.define_method(mapping[:to_method]) do |instance, doc|
          current = instance.instance_variable_get("@#{attr_sym}")
          if current.is_a?(Array)
            doc[mapping[:json_name]] = current.map do |item|
              item.respond_to?(:content) ? item.content : item
            end
          elsif current
            doc[mapping[:json_name]] =
              current.respond_to?(:content) ? current.content : current
          end
        end
      end
    end

    def collect_inline_child_mappings(assembly_def)
      model = assembly_def.model
      return [] unless model

      collect_model_child_mappings(model)
    end

    # ── Flag Handling ─────────────────────────────────────────────────

    def add_inline_flag(klass, flag_def)
      return unless flag_def.name

      attr_name = safe_attr(flag_def.name)
      type = TypeMapper.map(flag_def.as_type)
      klass.attribute attr_name, type
    end

    def add_flag_reference(klass, flag_ref)
      return unless flag_ref.ref

      flag_name = flag_ref.ref
      flag_def = @flag_defs[flag_name]
      attr_name = safe_attr(flag_name)
      type = flag_def ? TypeMapper.map(flag_def.as_type) : :string
      klass.attribute attr_name, type
    end

    # ── Choice Handling ───────────────────────────────────────────────

    def process_choice(klass, choice)
      choice.assembly&.each { |ar| add_assembly_reference(klass, ar) }
      choice.field&.each { |fr| add_field_reference(klass, fr) }
      choice.define_assembly&.each { |ad| add_inline_assembly(klass, ad) }
      choice.define_field&.each { |fd| add_inline_field(klass, fd) }
    end

    def process_choice_group(klass, choice_group)
      choice_group.assembly&.each do |ar|
        add_grouped_assembly_reference(klass, ar)
      end
      choice_group.field&.each { |fr| add_grouped_field_reference(klass, fr) }
      choice_group.define_assembly&.each { |ad| add_inline_assembly(klass, ad) }
      choice_group.define_field&.each { |fd| add_inline_field(klass, fd) }
    end

    def add_grouped_assembly_reference(klass, grouped_ref)
      ref_name = grouped_ref.ref
      return unless ref_name

      assembly_klass = @classes["Assembly_#{ref_name.gsub('-', '_')}"] ||
        create_placeholder_assembly(ref_name)

      attr_name = safe_attr(ref_name)
      klass.attribute attr_name, assembly_klass
    end

    def add_grouped_field_reference(klass, grouped_ref)
      ref_name = grouped_ref.ref
      return unless ref_name

      field_klass = @classes["Field_#{ref_name.gsub('-', '_')}"]
      return unless field_klass

      attr_name = safe_attr(ref_name)
      klass.attribute attr_name, field_klass
    end

    # ── Helpers ───────────────────────────────────────────────────────

    def scoped_field_name(field_name)
      base = "Field_#{field_name.gsub('-', '_')}"
      @current_assembly_name ? "#{base}_in_#{@current_assembly_name}" : base
    end

    def unbounded?(max_occurs)
      max_occurs == "unbounded" || (max_occurs.to_i > 1 && max_occurs != "1")
    end

    def create_placeholder_assembly(name)
      key = "Assembly_#{name.gsub('-', '_')}"
      @classes[key] ||= Class.new(Lutaml::Model::Serializable)
    end

    def add_any_content(klass)
      klass.attribute :any_content, :string
    end

    def add_json_root_handling(klass, json_root)
      klass.instance_variable_set(:@json_root_name, json_root)
      class << klass
        attr_reader :json_root_name
      end

      original_of_json = klass.method(:of_json)
      klass.define_singleton_method(:of_json) do |doc, options = {}|
        if doc.is_a?(Hash) && doc.key?(json_root_name)
          original_of_json.call(doc[json_root_name], options)
        else
          original_of_json.call(doc, options)
        end
      end

      original_to_json = klass.method(:to_json)
      klass.define_singleton_method(:to_json) do |instance, options = {}|
        json_str = original_to_json.call(instance, options)
        { json_root_name => JSON.parse(json_str) }.to_json
      end

      klass.send(:define_method, :to_json) do |options = {}|
        self.class.to_json(self, options)
      end

      # YAML root wrapping — mirrors JSON root handling
      original_of_yaml = klass.method(:of_yaml)
      klass.define_singleton_method(:of_yaml) do |doc, options = {}|
        if doc.is_a?(Hash) && doc.key?(json_root_name)
          original_of_yaml.call(doc[json_root_name], options)
        else
          original_of_yaml.call(doc, options)
        end
      end

      original_to_yaml = klass.method(:to_yaml)
      klass.define_singleton_method(:to_yaml) do |instance, options = {}|
        yaml_str = original_to_yaml.call(instance, options)
        data = YAML.safe_load(yaml_str,
                              permitted_classes: [Date, DateTime, Time, Symbol])
        { json_root_name => data }.to_yaml
      end

      klass.send(:define_method, :to_yaml) do |options = {}|
        self.class.to_yaml(self, options)
      end
    end

    # ── Constraint Validation Integration ──────────────────────────────

    def apply_constraint_validation(klass, constraint_def)
      return unless constraint_def

      # Store the constraint definition on the class for later access
      klass.instance_variable_set(:@metaschema_constraints, constraint_def)
      klass.define_singleton_method(:metaschema_constraints) do
        @metaschema_constraints
      end

      klass.define_method(:validate_constraints) do
        validator = ConstraintValidator.new
        validator.validate(self, self.class.metaschema_constraints)
      end
    end
  end
end
