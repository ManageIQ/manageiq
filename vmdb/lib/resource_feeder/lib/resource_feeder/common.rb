module ResourceFeeder
  module Common
    private
      def call_or_read(procedure_or_attributes, resource)
        case procedure_or_attributes
          when nil
            raise ArgumentError, "WTF is nil here? #{resource.inspect}"
          when Array
            attributes = procedure_or_attributes
            if attr = attributes.select { |a| resource.respond_to?(a) }.first
              resource.send attr
            end
          when Symbol
            attribute = procedure_or_attributes
            resource.send(attribute)
          when Proc
            procedure = procedure_or_attributes
            procedure.call(resource)
          else
            raise ArgumentError, "WTF is #{procedure_or_attributes.inspect} here? #{resource.inspect}"
        end
      end
  end
end
