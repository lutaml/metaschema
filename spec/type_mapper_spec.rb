# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metaschema::TypeMapper do
  describe ".map" do
    # Basic types
    it "maps string to :string" do
      expect(described_class.map("string")).to eq(:string)
    end

    it "maps token to :string" do
      expect(described_class.map("token")).to eq(:string)
    end

    it "maps boolean to :boolean" do
      expect(described_class.map("boolean")).to eq(:boolean)
    end

    it "maps integer to :integer" do
      expect(described_class.map("integer")).to eq(:integer)
    end

    it "maps decimal to :decimal" do
      expect(described_class.map("decimal")).to eq(:decimal)
    end

    # Integer subtypes
    {
      "positive-integer" => :integer,
      "negative-integer" => :integer,
      "non-positive-integer" => :integer,
      "non-negative-integer" => :integer,
    }.each do |as_type, expected|
      it "maps #{as_type} to #{expected}" do
        expect(described_class.map(as_type)).to eq(expected)
      end
    end

    # Date/time types — more precise than PR's :string mapping
    it "maps date to :date" do
      expect(described_class.map("date")).to eq(:date)
    end

    it "maps dateTime to :date_time" do
      expect(described_class.map("dateTime")).to eq(:date_time)
    end

    it "maps date-with-timezone to :date" do
      expect(described_class.map("date-with-timezone")).to eq(:date)
    end

    it "maps date-time-with-timezone to :date_time" do
      expect(described_class.map("date-time-with-timezone")).to eq(:date_time)
    end

    it "maps day-time-duration to :string" do
      expect(described_class.map("day-time-duration")).to eq(:string)
    end

    # String subtypes (from PR #18)
    {
      "uuid" => :string,
      "uri" => :string,
      "uri-reference" => :string,
      "email" => :string,
      "email-address" => :string,
      "hostname" => :string,
      "ip-address" => :string,
      "ip-v4-address" => :string,
      "ip-v6-address" => :string,
      "base64" => :string,
    }.each do |as_type, expected|
      it "maps #{as_type} to #{expected}" do
        expect(described_class.map(as_type)).to eq(expected)
      end
    end

    # Markup types
    it "maps markup-line to MarkupLineDatatype" do
      expect(described_class.map("markup-line")).to eq(Metaschema::MarkupLineDatatype)
    end

    it "maps markup-multiline to MarkupMultilineDatatype" do
      expect(described_class.map("markup-multiline")).to eq(Metaschema::MarkupMultilineDatatype)
    end

    it "returns :string for unknown types" do
      expect(described_class.map("unknown-type")).to eq(:string)
    end

    it "handles symbol input" do
      expect(described_class.map(:string)).to eq(:string)
    end
  end

  describe ".markup?" do
    it "returns true for markup-line" do
      expect(described_class.markup?("markup-line")).to be true
    end

    it "returns true for markup-multiline" do
      expect(described_class.markup?("markup-multiline")).to be true
    end

    it "returns false for string" do
      expect(described_class.markup?("string")).to be false
    end

    it "returns false for unknown types" do
      expect(described_class.markup?("unknown")).to be false
    end
  end

  describe ".multiline?" do
    it "returns true for markup-multiline" do
      expect(described_class.multiline?("markup-multiline")).to be true
    end

    it "returns false for markup-line" do
      expect(described_class.multiline?("markup-line")).to be false
    end

    it "returns false for string" do
      expect(described_class.multiline?("string")).to be false
    end
  end

  describe ".json_value_key" do
    it "returns RICHTEXT for markup-line" do
      expect(described_class.json_value_key("markup-line")).to eq("RICHTEXT")
    end

    it "returns prose for markup-multiline" do
      expect(described_class.json_value_key("markup-multiline")).to eq("prose")
    end

    it "returns STRVALUE as default for string" do
      expect(described_class.json_value_key("string")).to eq("STRVALUE")
    end

    it "returns STRVALUE as default for integer" do
      expect(described_class.json_value_key("integer")).to eq("STRVALUE")
    end

    it "returns STRVALUE as default for unknown types" do
      expect(described_class.json_value_key("unknown")).to eq("STRVALUE")
    end

    it "handles symbol input" do
      expect(described_class.json_value_key(:string)).to eq("STRVALUE")
    end
  end
end
