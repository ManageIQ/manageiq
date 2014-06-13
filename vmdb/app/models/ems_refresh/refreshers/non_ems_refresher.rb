module EmsRefresh::Refreshers
  class NonEmsRefresher < BaseRefresher
    def initialize(targets)
      @targets = targets
    end

    def refresh
      @targets.each do |target|
        host = target.kind_of?(Host) ? target : target.host
        if host.nil?
          $log.info "MIQ(NonEmsRefresher.refresh) Unable to refresh #{target.class} [#{target.id}]; No host found."
          next
        end

        next unless host.is_proxy_active?

        unless host.is_refreshable_now?
          $log.warn "MIQ(NonEmsRefresher.refresh) Unable to refresh Host: [#{host.name}] id: [#{host.id}] Message: [#{host.is_refreshable_now_error_message}]"
          next
        end

        host.miq_proxy.scan()
      end
    end
  end
end
