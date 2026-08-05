# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metaschema::ModelGenerator, ".to_ruby_source" do
  let(:metaschema_path) do
    "spec/fixtures/metaschema/test-suite/worked-examples/everything-metaschema/everything_metaschema.xml"
  end

  let(:oscal_path) do
    "spec/fixtures/oscal/src/metaschema/oscal_catalog_metaschema.xml"
  end

  let(:oscal_complete_path) do
    "spec/fixtures/oscal/src/metaschema/oscal_complete_metaschema.xml"
  end

  describe "with everything_metaschema" do
    let(:files) do
      described_class.to_ruby_source(metaschema_path,
                                     module_name: "TestEverything")
    end

    it "returns a hash with at least one file" do
      expect(files).to be_a(Hash)
      expect(files).not_to be_empty
    end

    it "produces valid Ruby syntax" do
      source = files.values.first
      expect { RubyVM::AbstractSyntaxTree.parse(source) }.not_to raise_error
    end

    it "wraps classes in the specified module" do
      source = files.values.first
      expect(source).to include("module TestEverything")
    end

    it "includes class definitions inheriting from Base" do
      source = files.values.first
      expect(source).to match(/class \w+ < Base/)
    end
  end

  describe "with OSCAL catalog metaschema" do
    let(:files) do
      described_class.to_ruby_source(oscal_path, module_name: "Oscal::V1_2_1")
    end

    it "produces valid Ruby syntax" do
      source = files.values.first
      expect { RubyVM::AbstractSyntaxTree.parse(source) }.not_to raise_error
    end

    it "includes a Catalog class" do
      source = files.values.first
      expect(source).to include("class Catalog < Base")
    end

    it "includes XML mappings" do
      source = files.values.first
      expect(source).to include('element "catalog"')
      expect(source).to include('map_element "metadata"')
    end

    it "includes key-value mappings" do
      source = files.values.first
      expect(source).to include("key_value do")
    end

    it "includes root wrapping for catalog" do
      source = files.values.first
      expect(source).to include("def self.of_json")
      expect(source).to include("def self.to_json")
    end
  end

  describe "with OSCAL complete metaschema" do
    let(:files) do
      described_class.to_ruby_source(oscal_complete_path, module_name: "Oscal::V1_2_1")
    end

    it "produces valid Ruby syntax for all classes" do
      source = files.values.first
      expect { RubyVM::AbstractSyntaxTree.parse(source) }.not_to raise_error
      # 122 named classes + anonymous inline types
      expect(source.scan(/class \w+ < Base/).length).to be >= 122
    end

    it "includes all 8 root model types" do
      source = files.values.first
      %w[Catalog Profile ComponentDefinition SystemSecurityPlan
         AssessmentPlan AssessmentResults PlanOfActionAndMilestones
         MappingCollection].each do |name|
        expect(source).to include("class #{name} < Base")
      end
    end

    it "uses symbol type references for class attributes" do
      source = files.values.first
      # Catalog's metadata attribute should use symbol reference
      catalog_start = source.index("class Catalog <")
      catalog_end = source.index("  end", catalog_start)
      catalog_source = source[catalog_start..catalog_end]
      expect(catalog_source).to include("attribute :metadata, :metadata")
    end

    it "declares the scalar field contract on field classes" do
      source = files.values.first
      expect(source).to include('scalar_field "content", collection: true')
    end

    it "puts the scalar field behaviour on Base, not on every field class" do
      source = files.values.first
      expect(source.scan("def of_json(doc, options = {})").length).to eq(1)
      expect(source.scan("def collapse_scalar(result)").length).to eq(1)
    end

    it "does not override from_json or from_yaml on field classes" do
      source = files.values.first
      # The inherited from_* already parses the document and delegates to of_*;
      # overriding it made emitted classes swallow raw JSON and YAML text.
      expect(source).not_to include("def self.from_json(")
      expect(source).not_to include("def self.from_yaml(")
    end

    it "emits no endless method definitions" do
      source = files.values.first
      # The gemspec floor is Ruby 2.7; endless definitions are 3.0+.
      expect(source).not_to match(/^\s*def [\w.]+\([^)]*\) =/)
    end

    it "rejects extra items for a non-collection SINGLETON_OR_ARRAY attribute" do
      source = files.values.first
      # metadata is singular: the runtime validates and raises rather than
      # silently dropping the extras.
      expect(source).to include(
        "raise Lutaml::Model::CollectionTrueMissingError.new(:metadata, instance.class)",
      )
    end
  end

  describe "field scalar declarations" do
    let(:source) do
      described_class.to_ruby_source(
        "spec/fixtures/scalar_fields_metaschema.xml", module_name: "TestScalar"
      ).values.first
    end

    it "keys the declaration off the field's own mapping key" do
      expect(source).to include('scalar_field "VALUE"')
    end

    it "uses the content key when the field has neither flags nor a value key" do
      plain = source[/class PlainText < Base.*?\n  end/m]
      expect(plain).to include('scalar_field "content", collection: false')
    end

    it "marks markup content as a collection" do
      rich = source[/class RichText < Base.*?\n  end/m]
      expect(rich).to include('scalar_field "content", collection: true')
    end

    it "declares nothing on an assembly that carries a content member" do
      # Holder has a :content attribute because it references a field named
      # `content`. Shape alone cannot tell an assembly from a field.
      holder = source[/class Holder < Base.*?\n  end/m]
      expect(holder).to include("attribute :content")
      expect(holder).not_to include("scalar_field")
    end
  end

  describe "custom callback ordering" do
    let(:emitter) { Metaschema::RubySourceEmitter.new({}, "Demo", nil) }
    let(:key) { ->(m) { emitter.send(:custom_method_sort_key, m) } }

    it "groups each field's from/to together (from first), ordered by subject" do
      names = %i[
        json_to_version_version json_from_version_version
        json_to_published_published json_from_published_published
      ]
      expect(names.sort_by(&key)).to eq(%i[
                                          json_from_published_published
                                          json_to_published_published
                                          json_from_version_version
                                          json_to_version_version
                                        ])
    end

    it "is deterministic regardless of input order" do
      forward = %i[json_from_a_a json_to_a_a json_from_b_b json_to_b_b]
      expect(forward.sort_by(&key)).to eq(forward.reverse.sort_by(&key))
    end

    # No fixture has a `valid-from`-shaped field name, so this regression is
    # unreachable through emitted source; a unit example is the only way to
    # pin it.
    it "does not read a direction token out of the middle of a field name" do
      names = %i[json_to_valid_from_valid_from json_from_valid_from_valid_from]
      expect(names.sort_by(&key)).to eq(%i[
                                          json_from_valid_from_valid_from
                                          json_to_valid_from_valid_from
                                        ])
    end
  end
end
