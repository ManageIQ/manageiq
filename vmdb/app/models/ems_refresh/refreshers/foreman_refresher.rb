require 'manageiq_foreman'
require 'manageiq_foreman/inventory'

module EmsRefresh
  module Refreshers
    class ForemanRefresher
      def self.refresh(providers)
        providers.each do |provider|
          EmsRefresh.refresh(provider.configuration_manager)
        end
      end
    end
  end
end
