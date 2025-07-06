# frozen_string_literal: true

require_relative 'markup_line_datatype'
require_relative 'markup_multiline_datatype'

module Metaschema
  module Constants
    ATTRIBUTE_TYPE_BY_DATA_TYPE = {
      'base64' => :string,
      'boolean' => :boolean,
      'date' => :string,
      'date-time' => :string,
      'date-time-with-timezone' => :string,
      'date-with-timezone' => :string,
      'day-time-duration' => :string,
      'decimal' => :float,
      'email-address' => :string,
      'hostname' => :string,
      'integer' => :integer,
      'ip-v4-address' => :string,
      'ip-v6-address' => :string,
      'markup-line' => MarkupLineDatatype,
      'markup-multiline' => MarkupMultilineDatatype,
      'non-negative-integer' => :integer,
      'positive-integer' => :integer,
      'string' => :string,
      'token' => :string,
      'uri' => :string,
      'uri-reference' => :string,
      'uuid' => :string
    }.freeze

    RESERVED_ATTRIBUTE_NAMES = %w[
      class
    ].freeze
  end
end
