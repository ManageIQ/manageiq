module AsyncDeleteMixin
  extend ActiveSupport::Concern
  included do
    def self._queue_task(task, ids)
      ids.each do |id|
        MiqQueue.put(
          :class_name  => name,
          :instance_id => id,
          :msg_timeout => 3600,
          :method_name => task.to_s
        )
      end
    end

    def self.delete_queue(ids)
      ids = ids.to_miq_a
      _log.info("Queuing delete of #{name} with the following ids: #{ids.inspect}")
      _queue_task(:delete, ids)
    end

    def self.destroy_queue(ids)
      ids = ids.to_miq_a
      _log.info("Queuing destroy of #{name} with the following ids: #{ids.inspect}")
      _queue_task(:destroy, ids)
    end

    def delete_queue
      _log.info("Queuing delete of #{self.class.name} with id: #{id}")
      self.class._queue_task(:delete, id.to_miq_a)
    end

    def destroy_queue
      _log.info("Queuing destroy of #{self.class.name} with id: #{id}")
      self.class._queue_task(:destroy, id.to_miq_a)
    end
  end
end
