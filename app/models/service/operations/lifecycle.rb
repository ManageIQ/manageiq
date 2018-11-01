module Service::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    api_relay_method :retire do |options|
      options
    end
  end
end
