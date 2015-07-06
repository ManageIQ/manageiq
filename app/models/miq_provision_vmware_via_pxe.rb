class MiqProvisionVmwareViaPxe < MiqProvisionVmware
  include_concern 'Cloning'
  include_concern 'Pxe'
  include_concern 'StateMachine'
end
