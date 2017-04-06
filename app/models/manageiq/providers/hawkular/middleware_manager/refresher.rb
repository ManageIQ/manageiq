module ManageIQ::Providers::Hawkular
  class MiddlewareManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin
  end
end
