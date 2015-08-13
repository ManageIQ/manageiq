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
      if defined?(self.class::Refresher) && self.class::Refresher != ManageIQ::Providers::BaseManager::Refresher
        self.class::Refresher
      else
        ::EmsRefresh::Refreshers.const_get("#{emstype.to_s.camelize}Refresher")
      end
    end
  end
end
