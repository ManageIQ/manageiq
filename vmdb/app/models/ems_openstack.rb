class EmsOpenstack < EmsCloud
  include EmsOpenstackMixin

  def self.ems_type
    @ems_type ||= "openstack".freeze
  end

  def self.description
    @description ||= "OpenStack".freeze
  end

  #
  # Operations
  #

  def vm_start(vm, options = {})
    vm.start
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_pause(vm, options = {})
    vm.pause
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, options = {})
    vm.suspend
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reset(vm, options = {})
    vm.reset
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end
end
