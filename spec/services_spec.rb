# frozen_string_literal: true

require "spec_helper"

# Helper: create an anonymous class with register support
def create_test_class(&block)
  Class.new(Lutaml::Model::Serializable, &block).tap do |klass|
    klass.define_singleton_method(:lutaml_default_register) { :default }
  end
end

RSpec.describe Metaschema::ModelGenerator::Services::FieldDeserializer do
  let(:deserializer) { described_class }

  # Create a minimal field class for testing
  let(:field_klass) do
    create_test_class do
      attribute :content, :string
      attribute :name, :string

      key_value do
        root "test_field"
        map "STRVALUE", to: :content
        map "name", to: :name
      end
    end
  end

  # Create a parent model class that has the field as an attribute
  let(:parent_klass) do
    fk = field_klass
    create_test_class do
      attribute :test_field, fk, collection: true

      key_value do
        root "parent"
      end
    end
  end

  describe "SINGLETON_OR_ARRAY normalization" do
    it "wraps a single Hash value into an array" do
      parent = parent_klass.new
      data = { "STRVALUE" => "hello" }
      deserializer.call(parent, :test_field, :json, data,
                        group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      value = parent.test_field
      expect(value).to be_a(Array)
      expect(value.length).to eq(1)
    end

    it "passes through an Array value unchanged" do
      parent = parent_klass.new
      data = [{ "STRVALUE" => "hello" }, { "STRVALUE" => "world" }]
      deserializer.call(parent, :test_field, :json, data,
                        group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      value = parent.test_field
      expect(value).to be_a(Array)
      expect(value.length).to eq(2)
    end

    it "compacts nil values when wrapping" do
      parent = parent_klass.new
      data = nil
      deserializer.call(parent, :test_field, :json, data,
                        group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      value = parent.test_field
      expect(value).to eq([])
    end
  end

  describe "non-SOA deserialization" do
    it "passes through data as-is when group_as is not SINGLETON_OR_ARRAY" do
      parent = parent_klass.new
      data = [{ "STRVALUE" => "hello" }]
      deserializer.call(parent, :test_field, :json, data,
                        group_as: nil, collapsible: false)
      value = parent.test_field
      expect(value).to be_a(Array)
      expect(value.length).to eq(1)
    end
  end
end

RSpec.describe Metaschema::ModelGenerator::Services::FieldSerializer do
  let(:serializer) { described_class }

  let(:field_klass) do
    create_test_class do
      attribute :content, :string, collection: true
      attribute :name, :string

      key_value do
        root "test_field"
        map "STRVALUE", to: :content
        map "name", to: :name
      end
    end
  end

  let(:parent_klass) do
    fk = field_klass
    create_test_class do
      attribute :test_field, fk, collection: true

      key_value do
        root "parent"
        map "test_field", to: :test_field
      end
    end
  end

  describe "SINGLETON_OR_ARRAY denormalization" do
    it "unwraps a single-element array to a scalar" do
      field = field_klass.new(content: ["hello"])
      parent = parent_klass.new(test_field: [field])
      doc = {}
      serializer.call(parent, :test_field, :json, doc,
                      group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      expect(doc).to have_key("test_field")
    end

    it "keeps multi-element arrays as arrays" do
      field1 = field_klass.new(content: ["hello"])
      field2 = field_klass.new(content: ["world"])
      parent = parent_klass.new(test_field: [field1, field2])
      doc = {}
      serializer.call(parent, :test_field, :json, doc,
                      group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      expect(doc).to have_key("test_field")
    end

    it "returns nil for nil attribute value" do
      parent = parent_klass.new
      doc = {}
      serializer.call(parent, :test_field, :json, doc,
                      group_as: "SINGLETON_OR_ARRAY", collapsible: false)
      expect(doc).to be_empty
    end
  end
end

RSpec.describe Metaschema::ModelGenerator::Services::CollapsiblesCollapser do
  let(:collapser_class) { described_class }

  it "groups instances by shared flag values" do
    model_klass = create_test_class do
      attribute :name, :string
      attribute :content, :string, collection: true

      key_value do
        root "prop"
        map "name", to: :name
        map "STRVALUE", to: :content
      end
    end

    collapsible_attrs = { name: model_klass.attributes[:name] }
    instances = [
      model_klass.new(name: "foo", content: ["value1"]),
      model_klass.new(name: "foo", content: ["value2"]),
      model_klass.new(name: "bar", content: ["value3"]),
    ]

    collapser = collapser_class.new(model_klass, collapsible_attrs, :json,
                                    instances)
    expect(collapser.collapsibles.length).to eq(3)

    result = collapser.call([{}, {}, {}])
    expect(result.length).to eq(2)
  end
end
