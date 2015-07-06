class MiqProvisionRedhatViaPxe < MiqProvisionRedhat
  include_concern 'Cloning'
  include_concern 'StateMachine'
end
