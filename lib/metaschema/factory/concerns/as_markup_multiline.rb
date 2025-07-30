# frozen_string_literal: true

require 'commonmarker'
require 'kramdown'

module Metaschema
  module Factory
    module AsMarkupMultiline
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def from_json(data, options = {})
          data = CommonMarker.render_html(data, :DEFAULT, %i[table])
          return if data.empty?

          doc = Nokogiri::XML(data)
          root = doc.create_element(mappings[:xml].root_element, 'xmlns' => mappings[:xml].namespace_uri)
          root.children = doc.children
          doc.children = root
          data = doc.to_xml

          from_xml(data, options)
        end

        def as(format, instance, options = {})
          return instance.as_markup_multiline(options) if format == :json

          super
        end
      end

      def as_markup_multiline(options = {})
        data = to_xml(options)
        data = Nokogiri::XML(data).root.inner_html
        data = Kramdown::Document.new(data, input: 'html').to_kramdown
        data.rstrip!
        data.gsub!(/\\(?=["'])/, '')
        data
      end
    end
  end
end
