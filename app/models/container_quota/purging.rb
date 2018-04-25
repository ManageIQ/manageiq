class ContainerQuota < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

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

      def purge_associated_records(ids)
        ContainerQuotaScope.where(:container_quota_id => ids).delete_all
        ContainerQuotaItem.where(:container_quota_id => ids).delete_all
      end
    end
  end
end
