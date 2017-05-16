class LoadBalancer
  module RetirementManagement
    extend ActiveSupport::Concern
    include RetirementMixin
  end
end
