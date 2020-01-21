class Compliance < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.compliances.history.keep_compliances.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.compliances.history.purge_window_size
      end

      def purge_scope(older_than = nil)
        where(arel_table[:timestamp].lteq(older_than))
      end

      def purge_associated_records(ids)
        ComplianceDetail.where(:compliance_id => ids).delete_all
      end
    end
  end
end
