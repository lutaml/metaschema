# frozen_string_literal: true

module Metaschema
  module Refinements
    module ObjectTry
      refine Object do
        def try(*args, **kwargs, &block)
          if args.empty? && kwargs.empty? && block_given?
            if block.arity.zero?
              instance_eval(&block)
            else
              yield self
            end
          elsif respond_to?(args.first)
            public_send(*args, **kwargs, &block)
          end
        end
      end

      refine NilClass do
        def try(*)
          nil
        end
      end
    end
  end
end
