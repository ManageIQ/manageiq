module EmsRefresh
  module Manager
    extend ActiveSupport::Concern
    module ClassMethods
      unless defined?(ems_type)
        def ems_type
        end
      end
    end

    unless defined?(emstype)
      def emstype
        self.class.ems_type
      end
    end
  end
end
