class BinaryBlob < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_timer
        purge_queue(:scope)
      end

      def purge_window_size
        ::Settings.binary_blob.purge_window_size
      end

      def purge_scope(_older_than = nil)
        where(:resource => nil)
      end
    end
  end
end
