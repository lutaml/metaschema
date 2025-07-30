# frozen_string_literal: true

require_relative '../../lib/metaschema/factory/utils'
require_relative '../../lib/metaschema/root'
require_relative '../../spec/support/model_helper'
require_relative '../../spec/support/path_helper'

RSpec.describe Metaschema::Root do
  include ModelHelper
  include PathHelper

  describe '#assemblies' do
    subject(:assemblies) { root.assemblies }

    schema_paths =
      root_dir
      .glob('spec/fixtures/metaschema/{examples/computer-example.xml,test-suite/**/*_metaschema.xml}')
      .sort

    wip_json_data_paths = %w[
      spec/fixtures/metaschema/test-suite/schema-generation/group-as/group-as-by-key_test_valid_PASS.json
      spec/fixtures/metaschema/test-suite/schema-generation/json-value-key/json-value-key-field_test_valid_PASS.json
    ]

    schema_paths.each do |schema_path|
      relative_schema_path = schema_path.relative_path_from(root_dir).to_s

      context "when schema is #{relative_schema_path}" do
        let(:root) { described_class.from_xml(schema_path.read) }

        around do |example|
          example.run
          puts @to_puts_on_failure if @to_puts_on_failure && example.exception # rubocop:disable RSpec/InstanceVariable
        end

        it { is_expected.to all(be_a_model).and(be_any) }

        schema_dir = schema_path.dirname
        data_paths =
          case relative_schema_path
          when 'spec/fixtures/metaschema/examples/computer-example.xml'
            []
          when 'spec/fixtures/metaschema/test-suite/schema-generation/dates-times/datatypes-datetime-no-tz_metaschema.xml' # rubocop:disable Layout/LineLength
            schema_dir.glob('datatypes-datetime-no{,-}tz_test_*_{FAIL,PASS}.{json,xml}')
          when 'spec/fixtures/metaschema/test-suite/schema-generation/token/datatypes-token_metaschema.xml'
            schema_dir.glob('{datatype-token-test-,datatypes-token_test_}*{FAIL,PASS}.{json,xml}')
          when %r{^spec/fixtures/metaschema/test-suite/worked-examples/.+_metaschema.xml$}
            schema_dir.glob('*.{json,xml}') - [schema_path]
          else
            schema_dir.glob(schema_path.basename.sub('_metaschema.xml', '_test_*_{FAIL,PASS}.{json,xml}'))
          end
          .sort

        data_paths.each do |data_path|
          relative_data_path = data_path.relative_path_from(root_dir).to_s

          case relative_data_path
          when /_PASS\.json$/
            wip = wip_json_data_paths.include?(relative_data_path)
            it "can roundtrip #{relative_data_path}", pending: ('not yet implemented' if wip) do # rubocop:disable RSpec/ExampleLength
              data = data_path.read
              model = create_json_parser(assemblies)

              case relative_data_path
              when 'spec/fixtures/metaschema/test-suite/schema-generation/datatypes/datatypes-token_test_valid_PASS.json' # rubocop:disable Layout/LineLength
                data.gsub!('"token-field":', '"token-fields":') # HACK: <group-as>'s @name is not respected?
              end

              generated_data = model.from_json(data).to_json(pretty: true)

              expect(JSON.parse(generated_data)).to eq(JSON.parse(data).except('$schema'))
            end
          when %r{^spec/fixtures/metaschema/test-suite/worked-examples/.+\.xml$|_PASS\.xml$}
            it "can roundtrip #{relative_data_path}" do # rubocop:disable RSpec/ExampleLength
              data = data_path.read
              root_name = Nokogiri::XML(data).root.name
              model = assemblies.find { |n| n.mappings.fetch(:xml).root_element == root_name }

              generated_data = model.from_xml(data).to_xml(pretty: true)

              @to_puts_on_failure = <<~MSG.chomp
                \n#{relative_data_path}
                <<<<<<< EXPECTED
                #{Nokogiri::XML(generated_data).to_xml.chomp}
                ======= VS
                #{data.chomp}
                >>>>>>> ACTUAL
              MSG

              expect(generated_data).to be_analogous_with(strip_xml_processing_instructions(data))
            end
          else # _FAIL.json, FAIL.xml
            pending "cannot roundtrip #{relative_data_path}"
          end
        end
      end
    end

    private

    def create_json_parser(assemblies) # rubocop:disable Metrics/MethodLength
      attrs = assemblies.filter_map.with_index do |assembly, index|
        name = assembly.mappings.fetch(:json).root_name
        next if name.nil?

        [:"attr#{index}", assembly, name]
      end

      Class.new(Lutaml::Model::Serializable) do
        attrs.each do |attr, type|
          attribute attr, type
        end

        json do
          attrs.each do |attr, _type, name|
            map name, to: attr, render_empty: :as_empty
          end
        end
      end
    end

    def strip_xml_processing_instructions(xml)
      xml.gsub(/<\?xml-.+?\?>/m, '')
    end
  end
end
