module Quadicons
  module LinkBuilders
    class ResourcePoolLinkBuilder < LinkBuilders::Base
      def url
        if context.show_links?
          super
        else
          ""
        end
      end
    end
  end
end
