# frozen_string_literal: true

require "spec_helper"

# Generates, evaluates and registers one metaschema's emitted source exactly
# once per module name. Evaluating the source and adding its Register to the
# global registry are both process-global and irreversible, so re-entry must
# not repeat either.
module EmittedParity
  LOADED = {} # rubocop:disable Style/MutableConstant

  class << self
    def load(fixture, module_name)
      LOADED[module_name] ||= evaluate_and_register(fixture, module_name)
    end

    private

    def evaluate_and_register(fixture, module_name)
      source = Metaschema::ModelGenerator
        .to_ruby_source(fixture, module_name: module_name).values.first
      TOPLEVEL_BINDING.eval(source) # rubocop:disable Security/Eval
      register(Object.const_get(module_name), module_name.downcase.to_sym)
    end

    def register(mod, register_id)
      register = Lutaml::Model::Register.new(register_id)
      Lutaml::Model::GlobalRegister.register(register)
      each_model(mod) do |name, klass|
        register.register_model(klass, id: snake_case(name).to_sym)
      end
      mod
    end

    def each_model(mod)
      mod.constants.each do |name|
        klass = mod.const_get(name)
        next unless klass.is_a?(Class) && klass < Lutaml::Model::Serializable

        yield(name.to_s, klass)
      end
    end

    def snake_case(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
    end
  end
end

# Executes the emitted Ruby source instead of string-matching it, and asserts it
# behaves the same as the in-memory classes the same metaschema generates.
#
# Every other emitter spec reads the source. Nothing loaded it and round-tripped
# data, which is how the emitted/runtime divergences shipped.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "emitted source parity" do
  # ── Document level: emitted output must match dynamic output ────────

  # Document-level emitted-vs-dynamic comparison runs on the scalar fields
  # fixture. Two divergences on the OSCAL catalog are out of this change's
  # scope and would otherwise mask a real regression here:
  #
  #   * every non-string builtin attribute type is emitted as :string
  #     (`type_reference` has no branch for Lutaml::Model::Type subclasses), so
  #     dateTime and boolean values differ in form between the two sides;
  #   * field-SOA to-callbacks render an empty collection the runtime omits.
  #
  # Both are present at the merge base and are reported separately.
  describe "whole-document serialization against the dynamic classes" do
    let(:scalar_path) { "spec/fixtures/scalar_fields_metaschema.xml" }

    let(:holder_xml) do
      <<~XML
        <HOLDER xmlns="http://example.com/ns/scalar-fields">
          <plain-text>hello</plain-text>
          <keyed-value>keyed</keyed-value>
          <flagged-text>flagged</flagged-text>
          <rich-text><p>one</p></rich-text>
        </HOLDER>
      XML
    end

    let(:dynamic) do
      Metaschema::ModelGenerator
        .generate_from_file(scalar_path)["Assembly_holder"]
    end

    let(:emitted) do
      EmittedParity.load(scalar_path, "EmittedParityScalar")::Holder
    end

    it "emits the same JSON as the dynamic classes" do
      expect(emitted.to_json(emitted.from_xml(holder_xml)))
        .to be_json_equivalent_to(dynamic.to_json(dynamic.from_xml(holder_xml)))
    end

    it "emits the same YAML as the dynamic classes" do
      expect(emitted.to_yaml(emitted.from_xml(holder_xml)))
        .to be_yaml_equivalent_to(dynamic.to_yaml(dynamic.from_xml(holder_xml)))
    end

    it "serializes a scalar field as a bare scalar, not an object" do
      json = JSON.parse(emitted.to_json(emitted.from_xml(holder_xml)))

      expect(json["HOLDER"])
        .to include("plain-text" => "hello", "keyed-value" => "keyed")
    end
  end

  describe "round-tripping a full OSCAL catalog through emitted source" do
    let(:catalog_path) do
      "spec/fixtures/oscal/src/metaschema/oscal_catalog_metaschema.xml"
    end

    let(:catalog_xml) do
      File.read("spec/fixtures/oscal/src/specifications/profile-resolution/" \
                "requirement-tests/catalogs/abc-simple_catalog.xml")
    end

    let(:emitted) do
      EmittedParity.load(catalog_path, "EmittedParityCatalog")::Catalog
    end

    it "reads its own JSON back and re-serializes identically" do
      json = emitted.to_json(emitted.from_xml(catalog_xml))
      once = emitted.to_json(emitted.from_json(json))

      expect(emitted.to_json(emitted.from_json(once)))
        .to be_json_equivalent_to(once)
    end

    it "reads its own YAML back and re-serializes identically" do
      yaml = emitted.to_yaml(emitted.from_xml(catalog_xml))
      once = emitted.to_yaml(emitted.from_yaml(yaml))

      expect(emitted.to_yaml(emitted.from_yaml(once)))
        .to be_yaml_equivalent_to(once)
    end
  end

  # ── Field collapse matrix ───────────────────────────────────────────
  #
  # The document-level examples above cannot reach the field collapse:
  # as_json/as_yaml class overrides only fire when something calls
  # Klass.as_json(instance) explicitly. This drives them directly.
  #
  # The OSCAL fixtures carry no json-value-key and no boolean flag, so the
  # matrix runs against a fixture written for it.

  describe "field collapse" do
    let(:scalar_path) { "spec/fixtures/scalar_fields_metaschema.xml" }

    let(:dynamic_classes) do
      Metaschema::ModelGenerator.generate_from_file(scalar_path)
    end

    let(:emitted_module) do
      EmittedParity.load(scalar_path, "EmittedParityScalar")
    end

    # Yields the dynamic and the emitted class for the same field.
    def both(field)
      dynamic = dynamic_classes["Field_#{field.tr('-', '_')}"]
      emitted = emitted_module.const_get(
        field.split("-").map(&:capitalize).join,
      )
      [dynamic, emitted]
    end

    def as_both(field, attrs)
      both(field).map { |klass| klass.as_json(klass.new(**attrs)) }
    end

    def as_yaml_both(field, attrs)
      both(field).map { |klass| klass.as_yaml(klass.new(**attrs)) }
    end

    it "collapses a default content key to a bare scalar" do
      expect(as_both("plain-text", content: "hello")).to eq(%w[hello hello])
    end

    it "collapses an explicit json-value-key field to a bare scalar" do
      expect(as_both("keyed-value", content: "hello")).to eq(%w[hello hello])
    end

    it "collapses a flagged field when no flag is set" do
      expect(as_both("flagged-text", content: "hello")).to eq(%w[hello hello])
    end

    # These two assert on keys rather than whole hashes: the emitted class types
    # its flag :string where the dynamic one uses Type::Boolean, so the flag
    # *values* differ in form. That is the out-of-scope `type_reference` gap
    # noted above, not a collapse difference.
    it "keeps object form when a flag is set" do
      dynamic, emitted = as_both("flagged-text", content: "hello", active: true)

      expect([dynamic.keys, emitted.keys]).to eq([%w[STRVALUE active]] * 2)
      expect(dynamic).to include("STRVALUE" => "hello")
    end

    it "keeps object form when a flag is set to false" do
      dynamic, emitted =
        as_both("flagged-text", content: "hello", active: false)

      expect([dynamic.keys, emitted.keys]).to eq([%w[STRVALUE active]] * 2)
    end

    it "collapses a one-element content array to a bare scalar" do
      expect(as_both("rich-text", content: ["one"])).to eq(%w[one one])
    end

    it "does not collapse an assembly that carries a content member" do
      dynamic = dynamic_classes["Assembly_holder"]
      emitted = emitted_module::Holder

      results = [dynamic, emitted].map do |klass|
        klass.as_json(klass.new(content: "x"))
      end

      expect(results).to eq([{ "content" => "x" }] * 2)
    end

    it "keeps object form for multi-item content" do
      dynamic, emitted = as_both("rich-text", content: %w[one two])

      expect(dynamic).to eq(emitted)
      expect(dynamic).to be_a(Hash)
    end

    it "collapses through as_yaml exactly as through as_json" do
      expect(as_yaml_both("plain-text", content: "hello"))
        .to eq(as_both("plain-text", content: "hello"))
    end

    it "keeps object form through as_yaml when a flag is set" do
      dynamic, emitted =
        as_yaml_both("flagged-text", content: "hi", active: true)

      expect([dynamic.keys, emitted.keys]).to eq([%w[STRVALUE active]] * 2)
    end
  end

  # ── Scalar input ────────────────────────────────────────────────────

  describe "scalar deserialization" do
    let(:scalar_path) { "spec/fixtures/scalar_fields_metaschema.xml" }

    let(:dynamic) do
      Metaschema::ModelGenerator
        .generate_from_file(scalar_path)["Field_plain_text"]
    end

    let(:emitted) do
      EmittedParity.load(scalar_path, "EmittedParityScalar")::PlainText
    end

    it "wraps an already-parsed scalar through of_json" do
      expect([dynamic, emitted].map { |k| k.of_json("hello").content })
        .to eq(%w[hello hello])
    end

    it "wraps an already-parsed scalar through of_yaml" do
      expect([dynamic, emitted].map { |k| k.of_yaml("hello").content })
        .to eq(%w[hello hello])
    end

    it "parses a JSON scalar document without keeping its quotes" do
      expect([dynamic, emitted].map { |k| k.from_json('"2026-08-04"').content })
        .to eq(%w[2026-08-04 2026-08-04])
    end

    it "does not accrete quotes across repeated JSON round-trips" do
      [dynamic, emitted].each do |klass|
        value = klass.new(content: "2026-08-04")
        3.times { value = klass.from_json(klass.to_json(value)) }

        expect(value.content).to eq("2026-08-04")
      end
    end

    it "parses a YAML scalar document instead of swallowing it" do
      parsed = [dynamic, emitted].map { |k| k.from_yaml("--- 2026-08-04\n") }

      expect(parsed.map(&:content)).to eq(%w[2026-08-04 2026-08-04])
    end

    it "does not accrete document markers across repeated YAML round-trips" do
      [dynamic, emitted].each do |klass|
        value = klass.new(content: "hello")
        3.times { value = klass.from_yaml(klass.to_yaml(value)) }

        expect(value.content).to eq("hello")
      end
    end
  end

  # ── Assembly SINGLETON_OR_ARRAY cardinality ─────────────────────────

  describe "non-collection SINGLETON_OR_ARRAY attributes" do
    let(:catalog_path) do
      "spec/fixtures/oscal/src/metaschema/oscal_catalog_metaschema.xml"
    end

    let(:dynamic) do
      Metaschema::ModelGenerator
        .generate_from_file(catalog_path)["Assembly_catalog"]
    end

    let(:emitted) do
      EmittedParity.load(catalog_path, "EmittedParityCatalog")::Catalog
    end

    let(:metadata) do
      { "title" => { "content" => ["T"] },
        "last-modified" => "2020-01-01T00:00:00Z",
        "version" => "1", "oscal-version" => "1.0" }
    end

    def deserialize(klass, value)
      instance = klass.new
      method = klass.instance_methods(false)
        .find { |m| m.to_s.start_with?("json_assembly_soa_from_metadata") }
      instance.send(method, instance, value)
      instance
    end

    it "accepts a single item for a non-collection attribute" do
      [dynamic, emitted].each do |klass|
        expect(deserialize(klass, [metadata]).metadata).not_to be_a(Array)
      end
    end

    it "rejects more than one item instead of dropping the extras" do
      [dynamic, emitted].each do |klass|
        expect { deserialize(klass, [metadata, metadata]) }
          .to raise_error(Lutaml::Model::CollectionTrueMissingError)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
