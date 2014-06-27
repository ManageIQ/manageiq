###################################
#
# EVM Automate Method: MiqHostProvision_Complete
#
# Notes: This method sends an e-mail when the following event is raised:
#
# Events: host_provisioned
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    host's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
###################################
begin
  @method = 'MiqHostProvision_Complete'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get the provisioning object
  prov = $evm.root['miq_host_provision_request'] || $evm.root['miq_host_provision']
  host = prov.host
  raise "#{@method} - Host not found" if host.nil?

  hostname = prov.get_option(:hostname)
  hostid = prov.get_option(:src_host_ids)

  # Get provisioning server
  miq_server = $evm.root['miq_server']

  # Override the default appliance IP Address below
  # appliance ||= 'evmserver.company.com'
  appliance ||= $evm.root['miq_server'].ipaddress

  #
  $evm.log("info", "#{@method} - Inspecting Host Object: #{host.inspect}") if @debug

  #
  # Get Host Owner Email
  #
  owner = nil
  owner ||= prov.get_option(:owner_email)
  $evm.log("info", "#{@method} - Host Owner: #{owner.inspect}") if @debug

  # to_email_address from owner.email then from model if nil
  to = owner || $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  # Set email Subject
  subject = "Your host provisioning request has Completed - Host: #{hostname}"

  # Set the opening body to Hello
  body = "Hello, "

  #
  # Host Provisioned Email Body
  #
  body += "<br><br>Your request to provision a host was approved and completed on #{Time.now.strftime('%A, %B %d, %Y at %I:%M%p')}. "
  body += "<br><br>Host: #{hostname}<b> will be available in approximately 15 minutes</b>. "
  body += "<br><br>If you are not already logged in, you can access and manage your host here <a href='https://#{appliance}/host/show/#{hostid}'>https://#{appliance}/host/show/#{hostid}</a>"
  body += "<br><br> If you have any issues with your new host please contact Support."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  #
  # Send email
  #
  $evm.log("info", "#{@method} - Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
  $evm.execute('send_email', to, from, subject, body)

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
