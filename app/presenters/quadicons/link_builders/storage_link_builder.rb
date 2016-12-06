module Quadicons
  module LinkBuilders
    class StorageLinkBuilder < LinkBuilders::Base
      def url
        return context.url_for(nil) unless context.show_links?

        if context.in_explorer_view?
          x_show_cid_url
        else
          super
        end
      end

      def x_show_cid_url
        context.url_for(:action => 'x_show', :id => ApplicationRecord.compress_id(record.id))
      end

      def html_options(given_options = {})
        opts = {}

        if context.in_explorer_view? && context.show_links?
          opts[:data] = {
            :miq_sparkle_on  => "",
            :miq_sparkle_off => ""
          }

          opts[:remote] = true
        end

        opts
      end
    end
  end
end
