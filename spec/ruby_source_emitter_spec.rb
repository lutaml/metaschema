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
      described_class.to_ruby_source(metaschema_path, module_name: "TestEverything")
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
      expect(catalog_source).to include('attribute :metadata, :metadata')
    end
  end
end
