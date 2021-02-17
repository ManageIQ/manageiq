module PerEmsTypeWorkerMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def workers
      return 0 unless any_valid_ems_in_zone?

      super
    end
  end
end
