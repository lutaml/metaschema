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

    it "emits scalar field (de)serialization on field classes" do
      source = files.values.first
      expect(source).to include("def self.of_yaml(doc, options = {})")
      expect(source).to include("new(content: doc)")
    end

    it "stores a non-collection SINGLETON_OR_ARRAY attribute as a single object" do
      source = files.values.first
      # metadata is singular: the SOA from-callback unwraps to a single value
      expect(source)
        .to include("instance.instance_variable_set(:@metadata, parsed.first)")
    end
  end

  describe "field scalar (de)serialization" do
    let(:emitter) { Metaschema::RubySourceEmitter.new({}, "Demo", nil) }
    let(:source) { emitter.send(:emit_field_scalar_methods, klass).join("\n") }

    context "with a non-collection content field" do
      let(:klass) do
        Class.new(Lutaml::Model::Serializable) { attribute :content, :string }
      end

      it "emits scalar of_json/from_json/of_yaml/from_yaml" do
        %w[of_json from_json of_yaml from_yaml].each do |m|
          expect(source).to include("def self.#{m}(")
        end
      end

      it "wraps a scalar into content", :aggregate_failures do
        expect(source).to include("data.is_a?(Hash) || data.is_a?(Array)")
        expect(source).to include("new(content: doc)")
        expect(source).to include("new(content: data)")
      end
    end

    context "with a collection content field (markup)" do
      let(:klass) do
        Class.new(Lutaml::Model::Serializable) do
          attribute :content, :string, collection: true
          attribute :em, :string, collection: true
        end
      end

      it "array-wraps the scalar into content" do
        expect(source).to include("new(content: [doc])")
      end

      it "emits an as_json/as_yaml collapse", :aggregate_failures do
        expect(source).to include("def self.as_json(")
        expect(source).to include("def self.as_yaml(")
        expect(source).to include('result.keys == ["content"]')
      end
    end

    context "with a real flag (not plain)" do
      let(:klass) do
        Class.new(Lutaml::Model::Serializable) do
          attribute :content, :string
          attribute :type, :string
        end
      end

      it "does not emit a collapse (flagged fields keep object form)" do
        expect(source).not_to include("def self.as_json(")
      end
    end

    context "without a content attribute" do
      let(:klass) do
        Class.new(Lutaml::Model::Serializable) { attribute :uuid, :string }
      end

      it "emits nothing" do
        expect(emitter.send(:emit_field_scalar_methods, klass)).to eq([])
      end
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
  end
end
