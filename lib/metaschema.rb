# frozen_string_literal: true

require 'lutaml/model'

Lutaml::Model::Config.configure do |config|
  require 'lutaml/model/xml_adapter/nokogiri_adapter'
  config.xml_adapter = Lutaml::Model::XmlAdapter::NokogiriAdapter
end

require_relative 'metaschema/version'
require_relative 'metaschema/root'

module Metaschema
  class Error < StandardError; end

  def self.validate(file_path)
    root = Root.from_file(file_path)
    root.validate_verbose
  end
end
