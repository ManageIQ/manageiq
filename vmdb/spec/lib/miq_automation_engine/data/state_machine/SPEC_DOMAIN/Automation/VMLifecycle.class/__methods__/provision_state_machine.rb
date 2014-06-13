STEPS   = %w(
  initial
  acquireIPAddress
  acquireMACAddress
  registerDNS
  registerCMDB
  registerAD
  provision
  checkProvision
  registerDHCP
  activateCMDB
  emailOwner
  final
)

DESCRIPTION = {
  STEPS[0]  => "Provisioning Initializing",
  STEPS[1]  => "Acquiring IP Address",
  STEPS[2]  => "Acquiring MAC Address",
  STEPS[3]  => "Registering VM in DNS",
  STEPS[4]  => "Registering VM in CMDB",
  STEPS[5]  => "Registering VM in ActiveDirectory",
  STEPS[6]  => "Provisioning",
  STEPS[7]  => "Checking Provision Status",
  STEPS[8]  => "Registering VM in DHCP",
  STEPS[9]  => "Activating VM in CMDB",
  STEPS[10] => "Emailing VM Owner",
  STEPS[11] => "Provisioning Complete",
}

def on_state_change(_from, _to, _message)
end

def log_error(msg, state, final_state)
  $evm.log("warn", msg) unless state == final_state
end

current     = $evm.current
$evm.log("info", "Listing CURRENT Object Attributes:")
current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")
step        = current['step']
step        = 'initial' if step.nil?  || step.empty?
step_index  = STEPS.index(step)
$evm.log("info", "STEP=<#{step}> INDEX=<#{step_index}>")

root        = $evm.root
$evm.log("info", "Listing ROOT Object Attributes:")
root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")
state       = root["ae_state"]
state       = 'initial' if state.nil? || state.empty?
state_index = STEPS.index(state)
$evm.log("info", "STATE=<#{state}> INDEX=<#{state_index}>")

result      = root["ae_result"]
$evm.log("info", "AE_RESULT=<#{result}>")

if step_index == (state_index - 1)
  message = 'create'
elsif step_index == state_index
  if result == 'retry'
    message = 'noop'
  else
    if result == 'error'
      message = 'error'
      final_state = STEPS.last
      new_state_index = STEPS.index(final_state)   # Go To FINAL state on Error
      log_error("Error in State=<#{STEPS[state_index]}>", state, final_state)
    else
      message = 'create'
      new_state_index = state_index + 1
      $evm.log("info", "Going from State=<#{STEPS[state_index]}> to <#{STEPS[new_state_index]}>")
    end

    root['ae_state'] = STEPS[new_state_index]

    on_state_change(STEPS[state_index], STEPS[new_state_index], message) unless state_index == new_state_index
  end
else
  message = 'noop'
end

$evm.log("info", "Setting AE_MESSAGE=<#{message}> STEP=<#{STEPS[step_index + 1]}>")
current['ae_message'] = message
current['step'] = STEPS[step_index + 1]
