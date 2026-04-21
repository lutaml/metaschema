# frozen_string_literal: true

module Metaschema
  class TypeMapper
    TYPE_MAP = {
      # Basic types
      "string" => :string,
      "token" => :string,
      "boolean" => :boolean,
      "integer" => :integer,
      "decimal" => :decimal,

      # Integer subtypes
      "positive-integer" => :integer,
      "negative-integer" => :integer,
      "non-positive-integer" => :integer,
      "non-negative-integer" => :integer,

      # Date/time types
      "date" => :date,
      "dateTime" => :date_time,
      "date-with-timezone" => :date,
      "date-time-with-timezone" => :date_time,

      # String subtypes
      "uuid" => :string,
      "uri" => :string,
      "email" => :string,
      "hostname" => :string,
      "ip-address" => :string,

      # Markup types — use Metaschema's own types
      "markup-line" => Metaschema::MarkupLineDatatype,
      "markup-multiline" => Metaschema::MarkupLineDatatype,
    }.freeze

    MARKUP_TYPES = %w[markup-line markup-multiline].freeze

    class << self
      def map(as_type)
        TYPE_MAP[as_type.to_s] || :string
      end

      def markup?(as_type)
        MARKUP_TYPES.include?(as_type.to_s)
      end

      def multiline?(as_type)
        as_type.to_s == "markup-multiline"
      end

      # Register format-specific serializers for types that lutaml-model
      # doesn't handle correctly out of the box.
      def register_serializers!
        # Decimal JSON — BigDecimal#to_s defaults to scientific
        # notation ("0.11e1"); JSON needs plain notation (1.1)
        Lutaml::Model::Type::Value.register_format_type_serializer(
          :json, Lutaml::Model::Type::Decimal,
          to: lambda { |inst|
            return nil unless inst.value

            v = inst.value
            v = Lutaml::Model::Type::Decimal.cast(v) unless v.is_a?(BigDecimal)
            v.to_f
          }
        )

        # Decimal XML — same scientific notation issue
        Lutaml::Model::Type::Value.register_format_type_serializer(
          :xml, Lutaml::Model::Type::Decimal,
          to: lambda { |inst|
            return nil unless inst.value

            v = inst.value
            v = Lutaml::Model::Type::Decimal.cast(v) unless v.is_a?(BigDecimal)
            v.to_s("F")
          }
        )
      end
    end
  end
end
