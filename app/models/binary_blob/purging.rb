class BinaryBlob < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_timer
        purge_queue(:orphaned, 'resource')
      end

      def purge_window_size
        ::Settings.binary_blob.purge_window_size
      end

      def purge_associated_records(ids)
        BinaryBlobPart.where(:binary_blob_id => ids).delete_all
      end
    end
  end
end
