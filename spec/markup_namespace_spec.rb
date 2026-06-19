# frozen_string_literal: true

require "spec_helper"

# Proves the architecture the emitter reproduces in Task 3: an OSCAL-namespaced
# parent whose markup child also carries the OSCAL namespace round-trips inline
# markup byte-for-byte (the shared Metaschema metaschema/1.0 types DROP the
# child element instead — see the plan's verified facts).
RSpec.describe "OSCAL-namespaced markup round-trip" do
  before(:all) do
    Metaschema::CodeType
    Metaschema::AnchorType
    Metaschema::InlineMarkupType
  end

  let(:oscal_ns) do
    Class.new(Lutaml::Xml::Namespace) do
      uri "http://csrc.nist.gov/ns/oscal/1.0"
      prefix_default nil
    end
  end

  let(:inline_type) do
    ns = oscal_ns
    Class.new(Lutaml::Model::Serializable) do
      attribute :content, :string, collection: true
      attribute :em, self, collection: true
      xml do
        element "inlineMarkupType"
        namespace ns
        mixed_content
        map_content to: :content
        map_element "em", to: :em
      end
    end
  end

  let(:parent_class) do
    ns = oscal_ns
    child = inline_type
    Class.new(Lutaml::Model::Serializable) do
      attribute :content, :string, collection: true
      attribute :strong, child, collection: true
      xml do
        element "p"
        namespace ns
        mixed_content
        map_content to: :content
        map_element "strong", to: :strong
      end
    end
  end

  it "preserves nested inline markup in the OSCAL default namespace" do
    src = %(<p xmlns="http://csrc.nist.gov/ns/oscal/1.0">a <strong>x <em>y</em> z</strong> c</p>)
    inst = parent_class.from_xml(src)
    out = parent_class.to_xml(inst).gsub(/\n\s*/, "")
    expect(out).to eq(src)
  end
end
