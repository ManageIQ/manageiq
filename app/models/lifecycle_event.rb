class LifecycleEvent < ApplicationRecord
  belongs_to :vm_or_template

  include UuidMixin

  def self.create_event(vm, event_hash)
    _log.debug(event_hash.inspect)

    # Update the location if not provided by getting the value from the vm
    event_hash[:location] = vm.path if event_hash[:location].blank? && vm.present?
    event = LifecycleEvent.new(event_hash)
    event.save!

    # create the event and link it to a Vm if a vm was found
    if vm.present? && !vm.lifecycle_events.include?(event)
      vm.lifecycle_events << event
    end
  end
end
