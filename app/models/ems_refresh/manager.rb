module EmsRefresh
  module Manager
    extend ActiveSupport::Concern
    module ClassMethods
      unless respond_to?(:ems_type)
        def ems_type
        end
      end
    end

    unless respond_to?(:emstype)
      def emstype
        self.class.ems_type
      end
    end

    def refresher
      self.class::Refresher
    end
  end
end
