module Quadicons
  class HostQuadicon < Base
    def quadrant_list
      if render_full?
        [:guest_count, :normalized_state, :host_vendor, :auth_status]
      else
        [:host_vendor]
      end
    end

    def render_single?
      !context.fetch_settings(:quadicons, :host)
    end

    def render_badge
      concat(Quadicons::Badge.new(record, context).render)
    end

    def link_builder
      LinkBuilders::HostLinkBuilder
    end
  end
end
