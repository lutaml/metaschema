# frozen_string_literal: true

require 'lutaml/model'

require_relative 'anchor_type'
require_relative 'image_type'
require_relative 'inline_markup_type'
require_relative 'insert_type'

module Metaschema
  class CodeType < Lutaml::Model::Serializable
    attribute :content, :string
    attribute :klass, :string
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

    xml do
      root 'codeType', mixed: true
      namespace 'http://csrc.nist.gov/ns/oscal/metaschema/1.0'

      map_content to: :content
      map_attribute 'class', to: :klass
      map_element 'a', to: :a
      map_element 'insert', to: :insert
      map_element 'br', to: :br
      map_element 'code', to: :code
      map_element 'em', to: :em
      map_element 'i', to: :i
      map_element 'b', to: :b
      map_element 'strong', to: :strong
      map_element 'sub', to: :sub
      map_element 'sup', to: :sup
      map_element 'q', to: :q
      map_element 'img', to: :img
    end
  end
end
