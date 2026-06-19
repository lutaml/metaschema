# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metaschema::MarkupConverter do
  # Minimal markup-line class mirroring FieldFactory.apply_markup_attributes,
  # restricted to the elements the examples need.
  def markup_line_class
    Class.new(Lutaml::Model::Serializable) do
      attribute :content, :string, collection: true
      attribute :a, Metaschema::AnchorType, collection: true
      attribute :em, Metaschema::InlineMarkupType, collection: true
      attribute :strong, Metaschema::InlineMarkupType, collection: true
      attribute :code, Metaschema::CodeType, collection: true
      attribute :q, Metaschema::InlineMarkupType, collection: true
      attribute :sub, Metaschema::InlineMarkupType, collection: true
      attribute :sup, Metaschema::InlineMarkupType, collection: true
      attribute :img, Metaschema::ImageType, collection: true
      attribute :insert, Metaschema::InsertType, collection: true
      xml do
        element "p"
        mixed_content
        map_content to: :content
        map_element "a", to: :a
        map_element "em", to: :em
        map_element "strong", to: :strong
        map_element "code", to: :code
        map_element "q", to: :q
        map_element "sub", to: :sub
        map_element "sup", to: :sup
        map_element "img", to: :img
        map_element "insert", to: :insert
      end
    end
  end

  # Minimal markup-multiline class with the block elements exercised here.
  # (List elements use a mutually-recursive datatype graph that is awkward to
  # reference from an anonymous class; paragraph/heading blocks suffice to cover
  # block ordering and block round-tripping.)
  def markup_multiline_class
    Class.new(Lutaml::Model::Serializable) do
      attribute :content, :string, collection: true
      attribute :p, Metaschema::InlineMarkupType, collection: true
      attribute :h1, Metaschema::InlineMarkupType, collection: true
      attribute :h2, Metaschema::InlineMarkupType, collection: true
      xml do
        element "prose"
        mixed_content
        map_content to: :content
        map_element "p", to: :p
        map_element "h1", to: :h1
        map_element "h2", to: :h2
      end
    end
  end

  describe ".to_markdown" do
    it "renders plain text" do
      inst = markup_line_class.from_xml("<p>Hello world</p>")
      expect(described_class.to_markdown(inst)).to eq("Hello world")
    end

    it "renders emphasis and strong interleaved with text" do
      inst = markup_line_class.from_xml("<p>a <em>b</em> c <strong>d</strong> e</p>")
      expect(described_class.to_markdown(inst)).to eq("a *b* c **d** e")
    end

    it "renders an anchor" do
      inst = markup_line_class.from_xml(%(<p>see <a href="http://x">link</a></p>))
      expect(described_class.to_markdown(inst)).to eq("see [link](http://x)")
    end

    it "renders code, q, sub, sup" do
      inst = markup_line_class.from_xml(
        "<p><code>x</code> <q>y</q> H<sub>2</sub>O E=mc<sup>2</sup></p>",
      )
      expect(described_class.to_markdown(inst)).to eq('`x` "y" H~2~O E=mc^2^')
    end

    it "renders an insert" do
      inst = markup_line_class.from_xml(
        %(<p>before <insert type="param" id-ref="p1"/> after</p>),
      )
      expect(described_class.to_markdown(inst)).to eq("before {{ insert: param, p1 }} after")
    end

    it "renders an image" do
      inst = markup_line_class.from_xml(%(<p><img alt="logo" src="a.png"/></p>))
      expect(described_class.to_markdown(inst)).to eq("![logo](a.png)")
    end
  end

  describe ".from_markdown" do
    def round_trip(md)
      inst = described_class.from_markdown(markup_line_class, md)
      described_class.to_markdown(inst)
    end

    it "parses plain text into content" do
      inst = described_class.from_markdown(markup_line_class, "Hello world")
      expect(inst.content.join).to eq("Hello world")
    end

    [
      "a *b* c **d** e",
      "see [link](http://x)",
      '`x` "y" H~2~O E=mc^2^',
      "before {{ insert: param, p1 }} after",
    ].each do |md|
      it "round-trips #{md.inspect}" do
        expect(round_trip(md)).to eq(md)
      end
    end

    it "round-trips nested markup (strong containing em)" do
      expect(round_trip("**bold *italic* tail**")).to eq("**bold *italic* tail**")
    end

    # xmlns declarations on child elements are normalized away by Canon in the
    # real cross-format spec; strip them here to keep the focus on interleaving.
    def interleaved_xml(klass, md)
      inst = described_class.from_markdown(klass, md)
      klass.to_xml(inst).gsub(/\n\s*/, "").gsub(/ xmlns="[^"]*"/, "")
    end

    it "reconstructs element_order so XML re-interleaves" do
      expect(interleaved_xml(markup_line_class, "a *b* c"))
        .to eq("<p>a <em>b</em> c</p>")
    end

    it "reconstructs element_order for nested markup XML" do
      expect(interleaved_xml(markup_line_class, "**bold *italic* tail**"))
        .to eq("<p><strong>bold <em>italic</em> tail</strong></p>")
    end
  end

  describe "markup-multiline blocks" do
    it "round-trips paragraphs and headings in source order" do
      klass = markup_multiline_class
      xml = "<prose><h2>Title</h2><p>Intro <em>text</em></p>" \
            "<p>Second para</p></prose>"
      inst = klass.from_xml(xml)
      md = described_class.to_markdown(inst)
      expect(md).to eq("## Title\n\nIntro *text*\n\nSecond para")

      rebuilt = described_class.from_markdown(klass, md)
      out = klass.to_xml(rebuilt).gsub(/\n\s*/, "").gsub(/ xmlns="[^"]*"/, "")
      expect(out).to eq(
        "<prose><h2>Title</h2><p>Intro <em>text</em></p>" \
        "<p>Second para</p></prose>",
      )
    end

    it "preserves block order from element_order (h1 after p)" do
      klass = markup_multiline_class
      inst = klass.from_xml("<prose><p>one</p><h1>two</h1></prose>")
      expect(described_class.to_markdown(inst)).to eq("one\n\n# two")
    end
  end
end
