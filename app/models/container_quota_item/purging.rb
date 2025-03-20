class ContainerQuotaItem < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    # According to 022e15256fd07fa7bf5b3ade7ce16b13daa87b84
    # This is necessary because ContainerQuotaItem may be archived due to edits
    # to parent ContainerQuota that is still alive.
    module ClassMethods
      def purge_date
        ::Settings.container_entities.history.keep_archived_quotas.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.container_entities.history.purge_window_size
      end

      def purge_scope(older_than)
        where(arel_table[:deleted_on].lteq(older_than))
      end

      def purge_method
        :destroy
      end
    end
  end
end
