module Quadicons
  module LinkBuilders
    class ServiceLinkBuilder < LinkBuilders::Base
      def url
        if context.show_links?
          x_show_cid_url
        else
          ""
        end
      end

      def x_show_cid_url
        context.url_for(:action => 'x_show', :id => ApplicationRecord.compress_id(record.id))
      end

      def html_options(given_options = {})
        opts = {}

        if context.show_links?
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
