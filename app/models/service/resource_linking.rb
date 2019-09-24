module Service::ResourceLinking
  extend ActiveSupport::Concern

  def add_provider_vms(provider, uid_ems_array)
    vm_uid_array = Array(uid_ems_array).compact.uniq
    raise _("no uid_ems_array defined for linking to service") if vm_uid_array.blank?

    options = {
      :target_class  => provider.class.name,
      :target_id     => provider.id,
      :uid_ems_array => vm_uid_array,
      :name          => "Linking VMs to service #{name} ID: [#{id}]",
      :userid        => evm_owner.userid,
      :sync_key      => guid,
      :service_id    => id,
      :zone          => my_zone
    }

    _log.info("NAME [#{options[:name]}] for user #{evm_owner.userid}")

    Service::LinkingWorkflow.create_job(options).tap do |job|
      job.signal(:start)
    end
  rescue => err
    _log.log_backtrace(err)
    raise
  end
end
