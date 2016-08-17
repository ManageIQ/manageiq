module Quadicons
  module LinkBuilders
    class MiqCimInstanceLinkBuilder < LinkBuilders::Base
      def url
        if context.show_links?
          if context.in_explorer_view?
            url_for(:action => 'x_show', :id => ApplicationRecord.compress_id(record.id))
          else
            url_for_record(record)
          end
        else
          url_for("")
        end
      end

      def html_options(given_options = {})
        if context.show_links? && context.in_explorer_view?
          {
            :data => {
              :miq_sparkle_on  => "",
              :miq_sparkle_off => ""
            }
          }
        else
          super
        end
      end
    end
  end
end
