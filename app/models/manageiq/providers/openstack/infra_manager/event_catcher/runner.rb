require 'workers/event_catcher'
require 'workers/mixins/event_catcher_openstack_mixin'

class ManageIQ::Providers::Openstack::InfraManager::EventCatcher < ::EventCatcher
  include ManageIQ::Providers::Openstack::EventCatcherMixin

  def add_openstack_queue(event_hash)
    EmsEvent.add_queue('add_openstack_infra', @cfg[:ems_id], event_hash)
  end
end
