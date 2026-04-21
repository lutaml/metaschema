# frozen_string_literal: true

# #
module Metaschema
  class ListType < Lutaml::Model::Serializable; end
  class BlockQuoteType < Lutaml::Model::Serializable; end

  class ListItemType < Lutaml::Model::Serializable
    attribute :content, :string, collection: true
    attribute :a, AnchorType, collection: true
    attribute :insert, InsertType, collection: true
    attribute :br, :string, collection: true
    attribute :code, CodeType, collection: true
    attribute :em, InlineMarkupType, collection: true
    attribute :i, InlineMarkupType, collection: true
    attribute :b, InlineMarkupType, collection: true
    attribute :strong, InlineMarkupType, collection: true
    attribute :sub, InlineMarkupType, collection: true
    attribute :sup, InlineMarkupType, collection: true
    attribute :q, InlineMarkupType, collection: true
    attribute :img, ImageType, collection: true
    attribute :ul, ListType, collection: true
    attribute :ol, OrderedListType, collection: true
    attribute :pre, PreformattedType, collection: true
    attribute :hr, :string, collection: true
    attribute :blockquote, BlockQuoteType, collection: true
    attribute :h1, InlineMarkupType, collection: true
    attribute :h2, InlineMarkupType, collection: true
    attribute :h3, InlineMarkupType, collection: true
    attribute :h4, InlineMarkupType, collection: true
    attribute :h5, InlineMarkupType, collection: true
    attribute :h6, InlineMarkupType, collection: true
    attribute :p, InlineMarkupType, collection: true

    xml do
      element "listItemType"
      mixed_content
      namespace ::Metaschema::Namespace

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
      map_element "ul", to: :ul
      map_element "ol", to: :ol
      map_element "pre", to: :pre
      map_element "hr", to: :hr
      map_element "blockquote", to: :blockquote
      map_element "h1", to: :h1
      map_element "h2", to: :h2
      map_element "h3", to: :h3
      map_element "h4", to: :h4
      map_element "h5", to: :h5
      map_element "h6", to: :h6
      map_element "p", to: :p
    end
  end
end
