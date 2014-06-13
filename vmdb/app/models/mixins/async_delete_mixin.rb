module AsyncDeleteMixin
  extend ActiveSupport::Concern
  included do
    def self._queue_task(task, ids)
      ids.each do |id|
        MiqQueue.put(
          :class_name  => self.name,
          :instance_id => id,
          :msg_timeout => 3600,
          :method_name => task.to_s
        )
      end
    end

    def self.delete_queue(ids)
      ids = ids.to_miq_a
      $log.info("MIQ(#{self.name}.delete_queue) Queuing delete of #{self.name} with the following ids: #{ids.inspect}")
      self._queue_task(:delete, ids)
    end

    def self.destroy_queue(ids)
      ids = ids.to_miq_a
      $log.info("MIQ(#{self.name}.destroy_queue) Queuing destroy of #{self.name} with the following ids: #{ids.inspect}")
      self._queue_task(:destroy, ids)
    end

    def delete_queue
      $log.info("MIQ(#{self.class.name}.delete_queue) Queuing delete of #{self.class.name} with id: #{self.id}")
      self.class._queue_task(:delete, self.id.to_miq_a)
    end

    def destroy_queue
      $log.info("MIQ(#{self.class.name}.destroy_queue) Queuing destroy of #{self.class.name} with id: #{self.id}")
      self.class._queue_task(:destroy, self.id.to_miq_a)
    end
  end
end
