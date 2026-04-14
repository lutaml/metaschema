# frozen_string_literal: true

module Metaschema
  class JsonValueKey < Lutaml::Model::Type::String
    xml do
      namespace ::Metaschema::Namespace
    end
  end
end
