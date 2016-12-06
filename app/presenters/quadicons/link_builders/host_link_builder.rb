module Quadicons
  module LinkBuilders
    class HostLinkBuilder < LinkBuilders::Base
      def url
        if context.edit_key?(:hostitems)
          "/host/edit/?selected_host=#{record.id}"
        else
          super
        end
      end
    end
  end
end
