# HACK: Allow calling FactoryGirl.create or FactoryGirl.build on anything.
module Spec
  module Support
    module MissingFactoryHelper
      def build(factory, *args, &block)
        factory_exists?(factory) ? super : class_from_symbol(factory).new(*args)
      end

      def create(factory, *args, &block)
        factory_exists?(factory) ? super : class_from_symbol(factory).create!(*args)
      end

      private

      def class_from_symbol(symbol)
        symbol.to_s.classify.constantize
      end

      def factory_exists?(factory)
        registered_factory_symbols.include?(factory.to_sym)
      end

      def registered_factory_symbols
        @registered_factory_symbols ||= begin
          require 'set'
          FactoryGirl.factories.collect { |i| i.name.to_sym }.to_set
        end
      end
    end
  end
end

FactoryGirl.singleton_class.prepend(Spec::Support::MissingFactoryHelper)
