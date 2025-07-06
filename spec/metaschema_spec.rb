# frozen_string_literal: true

require 'spec_helper'
require 'pathname'

require_relative '../lib/metaschema/root'

RSpec.describe Metaschema do
  fixtures_dir = Pathname.new(__dir__).join('fixtures')

  describe 'XML round-trip conversion' do
    xml_files = Dir[fixtures_dir.join('metaschema/test-suite/schema-generation', '**', '*_metaschema.xml')] +
                Dir[fixtures_dir.join('metaschema/examples', '*.xml')] +
                Dir[fixtures_dir.join('metaschema/test-suite/worked-examples', '**', '*_metaschema.xml')]

    # xml_files = [
    #   "spec/fixtures/metaschema/test-suite/schema-generation/allowed-values/allowed-values-basic_metaschema.xml",
    # # add more later
    # ]

    xml_files.each do |file_path|
      context "with file #{Pathname.new(file_path).relative_path_from(fixtures_dir)}" do
        # context "with file #{file_path}" do
        let(:xml_string) { File.read(file_path) }
        let(:parsed) { Metaschema::Root.from_xml(xml_string) }

        let(:generated) do
          parsed.to_xml(
            pretty: true,
            declaration: true,
            encoding: 'utf-8'
          )
        end

        it 'provides identical attribute access' do # rubocop:disable RSpec/ExampleLength
          reparsed = Metaschema::Root.from_xml(generated)

          expect(reparsed).to have_attributes(
            schema_name: parsed.schema_name,
            schema_version: parsed.schema_version,
            short_name: parsed.short_name,
            namespace: parsed.namespace,
            json_base_uri: parsed.json_base_uri
          )
        end

        it 'performs lossless round-trip conversion' do
          cleaned_xml_string = xml_string
                               .gsub(/^<\?xml-model.*\n/, '')
                               .gsub(/^<\?xml-stylesheet.*\n/, '')

          # puts "original---------"
          # puts cleaned_xml_string
          # puts "------"
          # puts generated

          expect(generated).to be_analogous_with(cleaned_xml_string)
        end
      end
    end
  end
end
