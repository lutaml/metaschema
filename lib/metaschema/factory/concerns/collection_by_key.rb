# frozen_string_literal: true

module Metaschema
  module Factory
    module CollectionByKey
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def apply_mappings(data, format, options = {})
          return of_json(data, options) if format == :json

          super
        end
      end
    end
  end
end
