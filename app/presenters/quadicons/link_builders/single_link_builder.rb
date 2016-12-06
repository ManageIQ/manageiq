module Quadicons
  module LinkBuilders
    class SingleLinkBuilder < LinkBuilders::Base
      def url
        if context.show_links?
          embedded_url
        else
          url_for("")
        end
      end

      def embedded_url
        if context.in_explorer_view?
          x_show_cid_url
        else
          url_for_record(record)
        end
      end

      def x_show_cid_url
        context.url_for(:action => 'x_show', :id => ApplicationRecord.compress_id(record.id))
      end
    end
  end
end
