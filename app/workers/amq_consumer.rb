client = ActiveMqClient.open(true)

ARGV.each do |arg|
  service, resource = arg.split('.')
  MiqQueue.subscribe_background_job(client, :service => service, :resource => resource)
end

loop do
  sleep(1)
end
