# frozen_string_literal: true

require 'commonmarker'
require 'kramdown'

module Metaschema
  module Factory
    module AsMarkupLine
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def from_json(data, options = {})
          data = CommonMarker.render_html(data, :DEFAULT, %i[table])
          return if data.empty?

          doc = Nokogiri::XML(data)
          doc.root.name = mappings[:xml].root_element
          doc.root.default_namespace = mappings[:xml].namespace_uri
          data = doc.to_xml

          from_xml(data, options)
        end

        def as(format, instance, options = {})
          return instance.as_markup_line(options) if format == :json

          super
        end
      end

      def as_markup_line(options = {})
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
