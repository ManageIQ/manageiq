module Quadicons
  class ConfigurationManagerQuadicon < Base
    def render_single?
      true
    end

    def quadrant_list
      [:config_vendor]
    end

    def link_builder
      LinkBuilders::ConfigurationManagerLinkBuilder
    end
  end
end
