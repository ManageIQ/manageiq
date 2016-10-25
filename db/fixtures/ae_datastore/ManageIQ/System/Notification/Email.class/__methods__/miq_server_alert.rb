def build_details(miq_server)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Build Email Subject
  subject = "#{alert} | EVM Server: [#{miq_server.name}]"

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>EVM Server <b>#{miq_server.name}</b> Properties:"
  body += "<br>EVM Server URL: <a href='https://#{miq_server.ipaddress}'>https://#{miq_server.ipaddress}</a>"
  body += "<br>Hostname: #{miq_server.hostname}"
  body += "<br>IP Address: #{miq_server.ipaddress}"
  body += "<br>MAC Address: #{miq_server.mac_address}"
  body += "<br>Last Heartbeat: #{miq_server.last_heartbeat}"
  body += "<br>Master: #{miq_server.is_master}"
  body += "<br>Status: #{miq_server.status}"
  body += "<br>Started On: #{miq_server.started_on}"
  body += "<br>Stopped On: #{miq_server.stopped_on}"
  body += "<br>Version: #{miq_server.version}"
  body += "<br>Zone: #{miq_server.zone}"
  body += "<br>Id: #{miq_server.id}"
  body += "<br><br>"

  body += "<br>Details:"
  body += "<br>Memory Percentage: #{miq_server.percent_memory}"
  body += "<br>Memory Usage: #{miq_server.memory_usage}"
  body += "<br>Memory Size: #{miq_server.memory_size}"
  body += "<br>CPU Percent: #{miq_server.percent_cpu}"
  body += "<br>CPU Time: #{miq_server.cpu_time}"
  body += "<br>Capabilities: #{miq_server.capabilities.inspect}"
  body += "<br><br>"

  body += "<br>Regards,"
  body += "<br>#{signature}"

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

miq_server = $evm.root['miq_server']
build_details(miq_server) unless miq_server.nil?
