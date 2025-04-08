# frozen_string_literal: true

require 'nokogiri'
require 'lutaml/model'

require_relative 'metaschema/version'
require_relative 'metaschema/root'

module Metaschema
  class Error < StandardError; end

  def self.validate(file_path)
    root = Root.from_file(file_path)
    root.validate_verbose
  end
end
