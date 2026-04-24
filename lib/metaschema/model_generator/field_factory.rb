# frozen_string_literal: true

module Metaschema
  class ModelGenerator
    # Creates field classes from Metaschema field definitions.
    # Each field class inherits from Lutaml::Model::Serializable and
    # includes XML + JSON mappings for the field's content and flags.
    class FieldFactory
      def initialize(field_def, generator)
        @field_def = field_def
        @g = generator
      end

      def create
        fd = @field_def
        return unless fd.name

        klass_name = "Field_#{fd.name.gsub('-', '_')}"
        klass = Class.new(Lutaml::Model::Serializable)
        @g.classes[klass_name] = klass

        is_markup = TypeMapper.markup?(fd.as_type)
        is_multiline = TypeMapper.multiline?(fd.as_type)
        content_type = TypeMapper.map(fd.as_type)

        if is_multiline
          self.class.apply_markup_multiline_attributes(klass)
        elsif is_markup
          self.class.apply_markup_attributes(klass)
        elsif fd.collapsible == "yes"
          klass.attribute :content, content_type, collection: true
        else
          klass.attribute :content, content_type
        end

        fd.define_flag&.each { |f| @g.add_inline_flag(klass, f) }
        fd.flag&.each { |f| @g.add_flag_reference(klass, f) }

        build_field_xml(klass, fd.name, is_markup || is_multiline,
                        fd, is_multiline)
        build_field_json(klass, fd)

        has_flags = fd.define_flag&.any? || fd.flag&.any?
        has_json_vk = fd.json_value_key || fd.json_value_key_flag
        is_collapsible = fd.collapsible == "yes"
        value_key = fd.json_value_key || TypeMapper.json_value_key(fd.as_type)

        klass.define_singleton_method(:of_json) do |data|
          if data.is_a?(String)
            new(content: data)
          else
            super(data)
          end
        end

        klass.define_singleton_method(:from_json) do |data|
          if data.is_a?(String)
            new(content: data)
          else
            super(data)
          end
        end

        if has_flags || has_json_vk || is_collapsible
          flag_attr_names = (fd.define_flag || []).filter_map do |f|
            Utils.safe_attr(f.name) if f.name
          end +
            (fd.flag || []).filter_map do |f|
              Utils.safe_attr(f.ref) if f.ref
            end

          orig_as_json = klass.method(:as_json)
          klass.define_singleton_method(:as_json) do |instance, options = {}|
            result = orig_as_json.call(instance, options)

            if is_collapsible && result.is_a?(Hash) && result[value_key].is_a?(Array) && result[value_key].length == 1
              result[value_key] = result[value_key].first
            end

            if (has_flags || has_json_vk) && result.is_a?(Hash) && result.key?(value_key)
              flags_present = flag_attr_names.any? do |attr|
                val = instance.send(attr)
                val && !(val.respond_to?(:using_default?) && val.using_default?)
              end
              unless flags_present
                return result[value_key]
              end
            end

            result
          end
        end

        @g.apply_constraint_validation(klass, fd.constraint)
      end

      class << self
        # Add inline markup attributes (a, code, em, etc.) for markup-line fields.
        def apply_markup_attributes(klass)
          klass.attribute :content, :string, collection: true
          klass.attribute :a, AnchorType, collection: true
          klass.attribute :insert, InsertType, collection: true
          klass.attribute :br, :string, collection: true
          klass.attribute :code, CodeType, collection: true
          klass.attribute :em, InlineMarkupType, collection: true
          klass.attribute :i, InlineMarkupType, collection: true
          klass.attribute :b, InlineMarkupType, collection: true
          klass.attribute :strong, InlineMarkupType, collection: true
          klass.attribute :sub, InlineMarkupType, collection: true
          klass.attribute :sup, InlineMarkupType, collection: true
          klass.attribute :q, InlineMarkupType, collection: true
          klass.attribute :img, ImageType, collection: true
        end

        # Add block-level markup attributes (p, h1-h6, ul, etc.) for markup-multiline fields.
        def apply_markup_multiline_attributes(klass)
          apply_markup_attributes(klass)
          klass.attribute :p, InlineMarkupType, collection: true
          klass.attribute :h1, InlineMarkupType, collection: true
          klass.attribute :h2, InlineMarkupType, collection: true
          klass.attribute :h3, InlineMarkupType, collection: true
          klass.attribute :h4, InlineMarkupType, collection: true
          klass.attribute :h5, InlineMarkupType, collection: true
          klass.attribute :h6, InlineMarkupType, collection: true
          klass.attribute :ul, ListType, collection: true
          klass.attribute :ol, OrderedListType, collection: true
          klass.attribute :pre, PreformattedType, collection: true
          klass.attribute :hr, :string, collection: true
          klass.attribute :blockquote, BlockQuoteType, collection: true
          klass.attribute :table, TableType, collection: true
        end
      end

      private

      def build_field_xml(klass, xml_element, is_markup, field_def,
is_multiline = false)
        flag_defs = field_def.define_flag || []
        flag_refs = field_def.flag || []

        flag_attr_maps = flag_defs.filter_map do |f|
          [f.name, Utils.safe_attr(f.name)] if f.name
        end
        flag_ref_maps = flag_refs.filter_map do |f|
          [f.ref, Utils.safe_attr(f.ref)] if f.ref
        end

        klass.class_eval do
          xml do
            element xml_element
            mixed_content if is_markup
            ordered if is_markup

            map_content to: :content

            if is_markup
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
            end

            if is_multiline
              map_element "p", to: :p
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
              map_element "table", to: :table
            end

            flag_attr_maps.each do |xml_name, attr_name|
              map_attribute xml_name, to: attr_name
            end

            flag_ref_maps.each do |xml_name, attr_name|
              map_attribute xml_name, to: attr_name
            end
          end
        end
      end

      def build_field_json(klass, field_def)
        flag_defs = field_def.define_flag || []
        flag_refs = field_def.flag || []
        has_flags = flag_defs.any? || flag_refs.any?
        json_vk = field_def.json_value_key
        json_vk_flag = field_def.json_value_key_flag&.flag_ref

        if json_vk_flag
          build_field_json_value_key_flag(klass, field_def, json_vk_flag)
          return
        end

        value_key = json_vk || TypeMapper.json_value_key(field_def.as_type)

        flag_attr_maps = flag_defs.filter_map do |f|
          [f.name, Utils.safe_attr(f.name)] if f.name
        end
        flag_ref_maps = flag_refs.filter_map do |f|
          [f.ref, Utils.safe_attr(f.ref)] if f.ref
        end

        klass.class_eval do
          key_value do
            root field_def.name

            if has_flags || json_vk
              map value_key, to: :content
            else
              map "content", to: :content
            end

            flag_attr_maps.each do |xml_name, attr_name|
              map xml_name, to: attr_name
            end

            flag_ref_maps.each do |xml_name, attr_name|
              map xml_name, to: attr_name
            end
          end
        end
      end

      def build_field_json_value_key_flag(klass, field_def, key_flag_ref)
        key_attr = Utils.safe_attr(key_flag_ref)
        flag_defs = field_def.define_flag || []
        flag_refs = field_def.flag || []

        other_flag_maps = flag_defs.reject { |f| f.name == key_flag_ref }
          .filter_map do |f|
          if f.name
            [f.name,
             Utils.safe_attr(f.name)]
          end
        end +
          flag_refs.reject { |f| f.ref == key_flag_ref }
            .filter_map do |f|
            if f.ref
              [f.ref,
               Utils.safe_attr(f.ref)]
            end
          end

        klass.instance_variable_set(:@json_vk_flag_key_attr, key_attr)
        klass.instance_variable_set(:@json_vk_flag_other_flag_maps,
                                    other_flag_maps)

        klass.class_eval do
          key_value do
            root field_def.name
            other_flag_maps.each do |json_name, attr_name|
              map json_name, to: attr_name
            end
          end
        end
      end
    end
  end
end
