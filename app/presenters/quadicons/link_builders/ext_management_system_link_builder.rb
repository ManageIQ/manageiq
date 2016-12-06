module Quadicons
  module LinkBuilders
    class ExtManagementSystemLinkBuilder < LinkBuilders::Base

      def html_options(given_options = {})
        given_options.merge(title: title_attr)
      end

      private

      # Build translation-friendly title
      def title_attr
        record.decorate.quadicon_title_str % record.decorate.quadicon_title_hash
      end
    end
  end
end
