module MiqRequestTask::PostInstallCallback
  extend ActiveSupport::Concern

  module ClassMethods
    def post_install_callback(id)
      p = find_by(:id => id.to_i)
      if p
        p.provision_completed_queue
      else
        _log.warn("task_id=#{id.inspect} not found")
      end
    end
  end

  def post_install_callback_url
    remote_ui_url = MiqRegion.my_region.remote_ui_url(:ipaddress)
    return nil if remote_ui_url.nil?
    "#{File.join(remote_ui_url, "miq_request/post_install_callback")}?task_id=#{id}"
  end

  def provision_completed_queue
    MiqQueue.put(
      :class_name     => self.class.name,
      :instance_id    => id,
      :method_name    => 'provision_completed',
      :zone           => my_zone,
      :role           => my_role,
      :tracking_label => tracking_label_id,
    )
  end

  def provision_completed
    post_install_callback
  end
end
