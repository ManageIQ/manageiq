module Spec
  module Support
    module TestContamination
      def self.setup
        TOPLEVEL_BINDING.eval('self').method(:include).owner.prepend(patched_include)
      end

      def self.patched_include
        Module.new do
          def include(included)
            exceptions = ["ActionView::Helpers::NumberHelper", "SNMP::BER"]
            return super if included.to_s.in?(exceptions)
            raise RuntimeError, "Unexpected module '#{included}' included globally, did you mean to include it in a class?", caller
          end
        end
      end
    end
  end
end
