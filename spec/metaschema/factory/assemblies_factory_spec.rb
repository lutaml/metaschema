# frozen_string_literal: true

require_relative '../../../lib/metaschema/factory/assemblies_factory'
require_relative '../../../lib/metaschema/root'
require_relative '../../../spec/support/model_helper'
require_relative '../../../spec/support/path_helper'

RSpec.describe Metaschema::Factory::AssembliesFactory do
  include ModelHelper
  include PathHelper

  describe '#call' do
    context 'when schema is spec/fixtures/metaschema/examples/computer-example.xml' do
      subject(:assemblies) do
        data = root_dir.join('spec/fixtures/metaschema/examples/computer-example.xml').read
        root = Metaschema::Root.from_xml(data)
        described_class.new(root).call
      end

      specify do # rubocop:disable RSpec/ExampleLength
        expect(assemblies).to match(
          [
            a_model('Vendor:Class'),
            a_model('Computer:Class'),
            a_model('Property:Class')
          ]
        )
      end

      it 'includes correct Vendor assembly', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        model = assemblies.fetch(0)

        expect(model).to be_a_model('Vendor:Class')

        # Attributes

        expect(model.attributes.values).to match(
          [
            be_an_attribute(:id, :string),
            be_an_attribute(:name, be_a_model('Name:Class')),
            be_an_attribute(:address, be_a_model('Address:Class')),
            be_an_attribute(:website, be_a_model('Website:Class'))
          ]
        )

        # JSON mapping

        json_mapping = model.mappings.fetch(:json)

        expect(json_mapping.root_name).to be_nil

        expect(json_mapping.mappings).to match(
          [
            have_attributes(name: 'id', to: :id),
            have_attributes(name: 'name', to: :name),
            have_attributes(name: 'address', to: :address),
            have_attributes(name: 'website', to: :website)
          ]
        )

        # XML mapping

        xml_mapping = model.mappings.fetch(:xml)

        expect(xml_mapping).to have_attributes(
          root_element: 'vendor',
          ordered?: true,
          mixed_content?: false,
          namespace_uri: 'http://example.com/ns/computer',
          namespace_prefix: nil
        )

        expect(xml_mapping.attributes).to match(
          [
            have_attributes(name: 'id', to: :id, delegate: nil)
          ]
        )

        expect(xml_mapping.content_mapping).to be_nil

        expect(xml_mapping.elements).to match(
          [
            have_attributes(name: 'name', to: :name, delegate: nil),
            have_attributes(name: 'address', to: :address, delegate: nil),
            have_attributes(name: 'website', to: :website, delegate: nil)
          ]
        )

        expect(xml_mapping.raw_mapping).to be_nil
      end

      it 'includes correct Computer assembly', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        model = assemblies.fetch(1)

        expect(model).to be_a_model('Computer:Class')

        # Attributes

        expect(model.attributes.values).to match(
          [
            be_an_attribute(:id, :string),
            be_an_attribute(:remarks, be_a_model('Remarks:Class')),
            be_an_attribute(:build_date, be_a_model('BuildDate:Class')),
            be_an_attribute(:prop, be_a_model('Property:Class')),
            be_an_attribute(:motherboard, be_a_model('Motherboard:Class')),
            be_an_attribute(:usb_devices, be_a_model('UsbDevice:Class'), options: { collection: true })
          ]
        )

        # JSON mapping

        json_mapping = model.mappings.fetch(:json)

        expect(json_mapping.root_name).to eq('computer')

        expect(json_mapping.mappings).to match(
          [
            have_attributes(name: 'id', to: :id),
            have_attributes(name: 'remarks', to: :remarks),
            have_attributes(name: 'build-date', to: :build_date),
            have_attributes(name: 'prop', to: :prop),
            have_attributes(name: 'motherboard', to: :motherboard),
            have_attributes(name: 'usb-devices', to: :usb_devices)
          ]
        )

        # XML mapping

        xml_mapping = model.mappings.fetch(:xml)

        expect(xml_mapping).to have_attributes(
          root_element: 'computer',
          ordered?: true,
          mixed_content?: false,
          namespace_uri: 'http://example.com/ns/computer',
          namespace_prefix: nil
        )

        expect(xml_mapping.attributes).to match(
          [
            have_attributes(name: 'id', to: :id, delegate: nil)
          ]
        )

        expect(xml_mapping.content_mapping).to be_nil

        expect(xml_mapping.elements).to match(
          [
            have_attributes(name: 'h1', to: :h1, delegate: :remarks),
            have_attributes(name: 'h2', to: :h2, delegate: :remarks),
            have_attributes(name: 'h3', to: :h3, delegate: :remarks),
            have_attributes(name: 'h4', to: :h4, delegate: :remarks),
            have_attributes(name: 'h5', to: :h5, delegate: :remarks),
            have_attributes(name: 'h6', to: :h6, delegate: :remarks),
            have_attributes(name: 'ul', to: :ul, delegate: :remarks),
            have_attributes(name: 'ol', to: :ol, delegate: :remarks),
            have_attributes(name: 'pre', to: :pre, delegate: :remarks),
            have_attributes(name: 'hr', to: :hr, delegate: :remarks),
            have_attributes(name: 'blockquote', to: :blockquote, delegate: :remarks),
            have_attributes(name: 'p', to: :p, delegate: :remarks),
            have_attributes(name: 'table', to: :table, delegate: :remarks),
            have_attributes(name: 'img', to: :img, delegate: :remarks),
            have_attributes(name: 'build-date', to: :build_date, delegate: nil),
            have_attributes(name: 'prop', to: :prop, delegate: nil),
            have_attributes(name: 'motherboard', to: :motherboard, delegate: nil),
            have_attributes(name: 'usb-device', to: :usb_devices, delegate: nil)
          ]
        )

        expect(xml_mapping.raw_mapping).to be_nil
      end

      it 'includes correct Property assembly', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        model = assemblies.fetch(2)

        expect(model).to be_a_model('Property:Class')

        # Attributes

        expect(model.attributes.values).to match(
          [
            be_an_attribute(:name, :string),
            be_an_attribute(:uuid, :string),
            be_an_attribute(:ns, :string, options: { default: 'http://example.com/ns/computer' }),
            be_an_attribute(:value, :string),
            be_an_attribute(:class_, :string),
            be_an_attribute(:group, :string),
            be_an_attribute(:remarks, be_a_model('Remarks:Class'))
          ]
        )

        # JSON mapping

        json_mapping = model.mappings.fetch(:json)

        expect(json_mapping.root_name).to be_nil

        expect(json_mapping.mappings).to match(
          [
            have_attributes(name: 'name', to: :name),
            have_attributes(name: 'uuid', to: :uuid),
            have_attributes(name: 'ns', to: :ns),
            have_attributes(name: 'value', to: :value),
            have_attributes(name: 'class', to: :class_),
            have_attributes(name: 'group', to: :group),
            have_attributes(name: 'remarks', to: :remarks)
          ]
        )

        # XML mapping

        xml_mapping = model.mappings.fetch(:xml)

        expect(xml_mapping).to have_attributes(
          root_element: 'prop',
          ordered?: true,
          mixed_content?: false,
          namespace_uri: 'http://example.com/ns/computer',
          namespace_prefix: nil
        )

        expect(xml_mapping.attributes).to match(
          [
            have_attributes(name: 'name', to: :name, delegate: nil),
            have_attributes(name: 'uuid', to: :uuid, delegate: nil),
            have_attributes(name: 'ns', to: :ns, delegate: nil),
            have_attributes(name: 'value', to: :value, delegate: nil),
            have_attributes(name: 'class', to: :class_, delegate: nil),
            have_attributes(name: 'group', to: :group, delegate: nil)
          ]
        )

        expect(xml_mapping.content_mapping).to be_nil

        expect(xml_mapping.elements).to match(
          [
            have_attributes(name: 'remarks', to: :remarks, delegate: nil)
          ]
        )

        expect(xml_mapping.raw_mapping).to be_nil
      end
    end
  end
end
