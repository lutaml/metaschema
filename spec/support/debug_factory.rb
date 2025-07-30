# frozen_string_literal: true

require_relative '../../lib/metaschema/factory/assemblies_factory'
require_relative '../../lib/metaschema/factory/assembly_factory'
require_relative '../../lib/metaschema/factory/field_factory'
require_relative '../../lib/metaschema/factory/utils/model_to_ruby'

module DebugFactory
  def self.included(base) # rubocop:disable Metrics/MethodLength
    return unless ENV['DEBUG_FACTORY'] # 'f' = when failure, other truthy = always

    base.around do |example|
      models = []
      [
        [Metaschema::Factory::AssembliesFactory, :create_collection],
        [Metaschema::Factory::AssemblyFactory, :call],
        [Metaschema::Factory::FieldFactory, :call]
      ].each do |klass, msg|
        klass.prepend(Module.new do
          define_method msg do |*args|
            model = super(*args)
            models << model
            model
          end
        end)
      end

      example.run

      next if example.exception.nil? && ENV['DEBUG_FACTORY'] == 'f'

      models.each do |model|
        puts nil, Metaschema::Factory::Utils::ModelToRuby.new(model)
      end
    end
  end
end
