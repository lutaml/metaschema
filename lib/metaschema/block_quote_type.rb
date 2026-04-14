# frozen_string_literal: true

module Metaschema
  class BlockQuoteType < Lutaml::Model::Serializable
    attribute :h1, InlineMarkupType, collection: true
    attribute :h2, InlineMarkupType, collection: true
    attribute :h3, InlineMarkupType, collection: true
    attribute :h4, InlineMarkupType, collection: true
    attribute :h5, InlineMarkupType, collection: true
    attribute :h6, InlineMarkupType, collection: true
    attribute :ul, ListType, collection: true
    attribute :ol, OrderedListType, collection: true
    attribute :pre, PreformattedType, collection: true
    attribute :hr, :string, collection: true
    attribute :blockquote, BlockQuoteType, collection: true
    attribute :p, InlineMarkupType, collection: true
    attribute :table, TableType, collection: true
    attribute :img, ImageType, collection: true

    xml do
      element "blockQuoteType"
      mixed_content
      namespace ::Metaschema::Namespace

      map_element "h1", to: :h1
      map_element "h2", to: :h2
      map_element "h3", to: :h3
      map_element "h4", to: :h4
      map_element "h5", to: :h5
      map_element "h6", to: :h6
      map_element "ul", to: :ul
      map_element "ol", to: :ol
      map_element "pre", to: :pre
      map_element "hr", to: :hr
      map_element "blockquote", to: :blockquote
      map_element "p", to: :p
      map_element "table", to: :table
      map_element "img", to: :img
    end
  end
end
