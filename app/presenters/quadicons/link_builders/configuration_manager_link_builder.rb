module Quadicons
  module LinkBuilders
    class ConfigurationManagerLinkBuilder < LinkBuilders::Base
      def url
        if !context.in_embedded_view?
          context.url_for(:action => 'x_show', :id => compressed_id)
        else
          ""
        end
      end

      private

      def compressed_id
        ApplicationRecord.compress_id(record.id)
      end
    end
  end
end
