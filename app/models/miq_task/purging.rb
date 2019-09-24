class MiqTask
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.task.history.keep_tasks.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.task.history.purge_window_size
      end

      def purge_scope(older_than)
        MiqTask.finished.where(arel_table[:created_on].lt(older_than))
      end

      def purge_associated_records(ids)
        Job.where(:miq_task_id => ids).delete_all
        LogFile.where(:miq_task_id => ids).delete_all
        BinaryBlob.where(:resource_type => 'MiqTask', :resource_id => ids).delete_all
      end
    end
  end
end
