class ManageIQ::Providers::InfraManager::Template < MiqTemplate
  default_value_for :cloud, false

  def self.display_name(number = 1)
    n_('Template', 'Templates', number)
  end

  def memory_for_request(request, _flavor_id = nil)
    memory = request.get_option(:vm_memory).to_i
    %w[amazon openstack google].include?(vendor) ? memory : memory.megabytes
  end

  def number_of_cpus_for_request(request, _flavor_id = nil)
    num_cpus = request.get_option(:number_of_sockets).to_i * request.get_option(:cores_per_socket).to_i
    num_cpus.zero? ? request.get_option(:number_of_cpus).to_i : num_cpus
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self, :host => host)
  end
end
