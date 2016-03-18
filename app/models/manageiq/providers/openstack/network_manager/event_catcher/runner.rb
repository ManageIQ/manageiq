class ManageIQ::Providers::Openstack::NetworkManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  def add_openstack_queue(event_hash)
    EmsEvent.add_queue('add_openstack_network', @cfg[:ems_id], event_hash)
  end
end
