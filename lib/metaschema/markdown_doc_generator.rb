# frozen_string_literal: true

module Metaschema
  # Generates human-readable Markdown documentation from a parsed Metaschema document.
  #
  # Usage:
  #   ms = Metaschema::Root.from_xml(File.read("metaschema.xml"))
  #   markdown = MarkdownDocGenerator.generate(ms)
  #   File.write("docs.md", markdown)
  #
  # The generator walks the metaschema definition tree and emits Markdown with:
  # - Schema title and version
  # - Table of contents
  # - Assembly, field, and flag definitions with descriptions
  # - Property tables showing types, constraints, and cardinality
  # - Examples from <example> elements
  class MarkdownDocGenerator
    def self.generate(metaschema)
      new(metaschema).generate
    end

    def initialize(metaschema)
      @metaschema = metaschema
      @output = []
    end

    def generate
      header
      table_of_contents
      definitions
      @output.join("\n")
    end

    private

    def header
      title = extract_text(@metaschema.schema_name) || "Metaschema"
      version = extract_text(@metaschema.schema_version)
      @output << "# #{title}"
      @output << ""
      @output << "**Version:** #{version}" if version
      @output << "" if version
    end

    def table_of_contents
      assemblies = @metaschema.define_assembly || []
      fields = @metaschema.define_field || []
      flags = @metaschema.define_flag || []

      items = assemblies.map do |a|
        "- [#{a.name} (Assembly)](##{anchor(a.name)})"
      end
      fields.each { |f| items << "- [#{f.name} (Field)](##{anchor(f.name)})" }
      flags.each { |f| items << "- [#{f.name} (Flag)](##{anchor(f.name)})" }

      return if items.empty?

      @output << "## Table of Contents"
      @output << ""
      items.each { |i| @output << i }
      @output << ""
    end

    def definitions
      (@metaschema.define_assembly || []).each { |a| assembly_section(a) }
      (@metaschema.define_field || []).each { |f| field_section(f) }
      (@metaschema.define_flag || []).each { |f| flag_section(f) }
    end

    # ── Assembly ───────────────────────────────────────────────────────

    def assembly_section(asm)
      @output << "## #{asm.name}"
      @output << ""
      formal_name_and_description(asm)

      # Flags
      flag_rows = (asm.define_flag || []).map do |f|
        flag_row(f, inline: true)
      end
      (asm.flag || []).each do |f|
        flag_rows << ["`#{f.ref}`", "flag", f.required == "yes" ? "Yes" : "No",
                      "-"]
      end

      # Model children
      model = asm.model
      child_rows = []
      if model
        (model.field || []).each { |fr| child_rows << field_ref_row(fr) }
        (model.assembly || []).each { |ar| child_rows << assembly_ref_row(ar) }
        (model.define_field || []).each do |fd|
          child_rows << inline_field_row(fd)
        end
        (model.define_assembly || []).each do |ad|
          child_rows << inline_assembly_row(ad)
        end
        (model.choice || []).each do |c|
          (c.field || []).each do |fr|
            child_rows << field_ref_row(fr, choice: true)
          end
          (c.assembly || []).each do |ar|
            child_rows << assembly_ref_row(ar, choice: true)
          end
          (c.define_field || []).each do |fd|
            child_rows << inline_field_row(fd, choice: true)
          end
          (c.define_assembly || []).each do |ad|
            child_rows << inline_assembly_row(ad, choice: true)
          end
        end
        (model.choice_group || []).each do |cg|
          child_rows << choice_group_row(cg)
        end
      end

      unless flag_rows.empty? && child_rows.empty?
        @output << "### Properties"
        @output << ""
        @output << "| Name | Type | Required | Description |"
        @output << "|------|------|----------|-------------|"
        flag_rows.each { |r| @output << "| #{r.join(' | ')} |" }
        child_rows.each { |r| @output << "| #{r.join(' | ')} |" }
        @output << ""
      end

      constraints_section(asm.constraint)
      examples_section(asm.example)

      @output << "---"
      @output << ""
    end

    # ── Field ──────────────────────────────────────────────────────────

    def field_section(fd)
      @output << "## #{fd.name}"
      @output << ""
      formal_name_and_description(fd)

      @output << "- **Type:** `#{fd.as_type || 'string'}`"
      @output << "- **Collapsible:** #{fd.collapsible == 'yes' ? 'Yes' : 'No'}" if fd.collapsible == "yes"

      # Flags on this field
      flag_rows = (fd.define_flag || []).map { |f| flag_row(f, inline: true) }
      (fd.flag || []).each do |f|
        flag_rows << ["`#{f.ref}`", "flag", f.required == "yes" ? "Yes" : "No",
                      "-"]
      end

      if flag_rows.any?
        @output << ""
        @output << "### Flags"
        @output << ""
        @output << "| Name | Type | Required | Description |"
        @output << "|------|------|----------|-------------|"
        flag_rows.each { |r| @output << "| #{r.join(' | ')} |" }
      end

      @output << ""
      constraints_section(fd.constraint)
      examples_section(fd.example)

      @output << "---"
      @output << ""
    end

    # ── Flag ───────────────────────────────────────────────────────────

    def flag_section(fl)
      @output << "## #{fl.name}"
      @output << ""
      formal_name_and_description(fl)

      @output << "- **Type:** `#{fl.as_type || 'string'}`"
      @output << ""

      constraints_section(fl.constraint)
      @output << "---"
      @output << ""
    end

    # ── Constraint helpers ─────────────────────────────────────────────

    def constraints_section(constraint)
      return unless constraint

      allowed = constraint.allowed_values
      matches = constraint.matches

      parts = []

      if allowed
        Array(allowed).each do |av|
          target = av.respond_to?(:target) ? (av.target || ".") : "."
          values = Array(av.enum).filter_map(&:value)
          allow_other = av.allow_other == "yes"
          level = av.level || "ERROR"
          next if values.empty?

          desc = "Allowed values for `#{target}`: #{values.map do |v|
            "`#{v}`"
          end.join(', ')}"
          desc += " (or other)" if allow_other
          desc += " [#{level}]"
          parts << desc
        end
      end

      if matches
        Array(matches).each do |m|
          target = m.target || "."
          if m.regex
            parts << "Matches regex `/#{m.regex}/` on `#{target}`"
          elsif m.datatype
            parts << "Matches datatype `#{m.datatype}` on `#{target}`"
          end
        end
      end

      return if parts.empty?

      @output << "### Constraints"
      @output << ""
      parts.each { |p| @output << "- #{p}" }
      @output << ""
    end

    # ── Examples ───────────────────────────────────────────────────────

    def examples_section(examples)
      return unless examples && !examples.empty?

      @output << "### Examples"
      @output << ""

      Array(examples).each_with_index do |ex, i|
        name = ex.description&.content || "Example #{i + 1}"
        @output << "#### #{name}"
        @output << ""
        if ex.remarks&.content
          @output << ex.remarks.content
          @output << ""
        end
      end
    end

    # ── Row builders ───────────────────────────────────────────────────

    def field_ref_row(fr, choice: false)
      ref = fr.ref
      group_as = fr.group_as
      json_name = group_as&.name || fr.use_name&.content || ref
      cardinality = cardinality_str(fr.min_occurs, fr.max_occurs, group_as)
      prefix = choice ? "*choice* " : ""
      ["`#{json_name}`", "#{prefix}field `#{ref}`", cardinality, ""]
    end

    def assembly_ref_row(ar, choice: false)
      ref = ar.ref
      group_as = ar.group_as
      json_name = group_as&.name || ref
      cardinality = cardinality_str(ar.min_occurs, ar.max_occurs, group_as)
      prefix = choice ? "*choice* " : ""
      ["`#{json_name}`", "#{prefix}assembly `#{ref}`", cardinality, ""]
    end

    def inline_field_row(fd, choice: false)
      return [] unless fd.name

      prefix = choice ? "*choice* " : ""
      ["`#{fd.name}`", "#{prefix}field (inline)", "-", ""]
    end

    def inline_assembly_row(ad, choice: false)
      return [] unless ad.name

      prefix = choice ? "*choice* " : ""
      ["`#{ad.name}`", "#{prefix}assembly (inline)", "-", ""]
    end

    def choice_group_row(cg)
      group_as = cg.group_as
      json_name = group_as&.name || "choice-group"
      ["`#{json_name}`", "choice group", cardinality_str(nil, nil, group_as),
       ""]
    end

    def flag_row(fl, inline: false)
      name = fl.name
      type = fl.as_type || "string"
      desc = extract_description(fl)
      ["`#{name}`", "flag `#{type}`", fl.required == "yes" ? "Yes" : "No", desc]
    end

    # ── Helpers ────────────────────────────────────────────────────────

    def formal_name_and_description(defn)
      formal = defn.formal_name
      if formal && !formal.is_a?(TrueClass)
        text = formal.is_a?(String) ? formal : formal.content
        @output << "**#{text}**" if text && !text.empty?
        @output << ""
      end

      desc = extract_description(defn)
      if desc && !desc.empty?
        @output << desc
        @output << ""
      end
    end

    def extract_description(defn)
      return nil unless defn.respond_to?(:description) && defn.description

      if defn.description.respond_to?(:content)
        defn.description.content
      else
        defn.description.to_s
      end
    end

    def extract_text(value)
      return nil unless value

      if value.respond_to?(:content)
        value.content
      elsif value.is_a?(String)
        value
      else
        value.to_s
      end
    end

    def cardinality_str(min, max, group_as)
      min_val = min.to_i
      max_val = max == "unbounded" ? nil : max&.to_i

      if group_as
        "1..#{max_val || '*'}" if min_val >= 0
      elsif min_val.positive? && max_val
        "#{min_val}..#{max_val}"
      elsif min_val.positive?
        "#{min_val}..*"
      else
        "0..1"
      end
    end

    def anchor(name)
      name.downcase.gsub(/[^a-z0-9-]/, "-")
    end
  end
end
