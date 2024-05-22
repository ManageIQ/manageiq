module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports(:retire) { unsupported_reason(:action) }

    api_relay_method :retire do |options|
      options
    end

    api_relay_method :retire_now, :retire
  end
end
