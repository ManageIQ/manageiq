class BinaryBlob < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_mode_and_value
        [:scope, purge_date]
      end

      def purge_date
        ::Settings.binary_blob.keep_orphaned.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.binary_blob.purge_window_size
      end

      def purge_scope(older_than = nil)
        where(:resource => nil).or(
          where(
            arel_table[:resource_type].eq("StateVarHash").and(
              arel_table[:resource_id].gt(- older_than.to_i)
            )
          )
        )
      end

      def purge_associated_records(ids)
        BinaryBlobPart.where(:binary_blob_id => ids).delete_all
      end
    end
  end
end
