module DisplayObject
  def self.log_service_resources(service)
    puts "Service has <#{service.service_resources.count}> service resources"
    service.service_resources.sort_by(&:id).each do |sr|
      puts "  Service Resource: ID: <#{sr.id}> Type: <#{sr.resource_type}>"
      next if sr.resource.nil?
      puts "  Service Resource Resource: ID: <#{sr.resource.id}> Type: <#{sr.resource.type}>"
      if sr.resource.respond_to?(:retired)
        puts "  Service Resource Resource is retirable. retired: <#{sr.resource.retired}> retires_on: <#{sr.resource.retires_on}> retirement_state: <#{sr.resource.retirement_state}>"
      else
        puts "  Service Resource Resource is not retirable"
      end
      if sr.resource.respond_to?(:my_zone)
        puts "  Service Resource Resource has a zone, Zone Name: <#{sr.resource.my_zone}>"
      else
        puts "  Service Resource Resource does not have a zone."
      end
    end
    puts "---------------------------------------------------------------"
  end

  def self.log_request_tasks(request)
    if request.miq_request_tasks.empty?
      puts "  Request Options: <#{request.options.inspect}>" if request.options.presence
      puts "  Request tasks do not exist."
      puts ""
    else
      request.miq_request_tasks.sort_by(&:id).each do |t|
        puts "  Task: ID: <#{t.id}> Type: <#{t.type}> State: <#{t.state}> Description: <#{t.description}> Request_message: <#{t.message}>"
        puts "  Task: ID: <#{t.id}> Executed_on_servers Options: <#{t.options[:executed_on_servers].inspect}>" if t.options[:executed_on_servers].presence
        puts "  Task: ID: <#{t.id}> Options: <#{t.options.inspect}>" if t.options.presence
      end
    end
    puts "---------------------------------------------------------------"
  end

  def self.log_request_info(request)
    puts "---------------------------------------------------------------"
    puts "  Request ID: <#{request.id}> Type: <#{request.type}> Description: <#{request.description}>"
    puts "  Request Status: <#{request.status}> State: <#{request.request_state}>"
    puts "  Request Message: <#{request.message}>"
    puts "  Request has <#{request.miq_request_tasks.count}> tasks"
    puts "---------------------------------------------------------------"
    DisplayObject.log_request_tasks(request)
  end

  def self.log_service_info(service)
    puts "---------------------------------------------------------------"
    puts "Service: ID: <#{service.id}> Name: <#{service.name}>"
    puts "Provisioned from Service Template: <#{service.miq_request.source.name}> type: <#{service.miq_request.source.type}> id: <#{service.miq_request.source.id}> service type: <#{service.miq_request.source.service_type}>"
    if service.respond_to?(:my_zone)
      puts "Service has a zone, Zone Name: <#{service.my_zone}> "
    else
      puts "Service does not have a zone."
    end
    puts "Service has parent Service: ID <#{service.parent.id}> Name: <#{service.parent.name}>" if service.parent
    puts "---------------------------------------------------------------" if service.parent
  end

  def self.log_service_children(service)
    puts "Service has #{service.all_service_children.count} child Service(s)" if service.all_service_children
    service.all_service_children.each do |cs|
      puts "Child Service: ID: #{cs.id} Name: #{cs.name}"
      DisplayObject.inspect_service(cs)
    end
  end

  def self.get_service_from_request(request)
    return if request.miq_request_tasks.first.nil?
    if request.miq_request_tasks.first.destination.presence
      if request.miq_request_tasks.first.destination.kind_of?(Service)
        request.miq_request_tasks.first.destination
      end
    end
  end

  def self.inspect_service(service, log_request = false)
    DisplayObject.log_service_info(service)
    DisplayObject.log_request_info(service.miq_request) if log_request
    DisplayObject.log_service_resources(service)
    DisplayObject.log_service_children(service)
  end

  def self.inspect_request(request)
    service = DisplayObject.get_service_from_request(request)
    puts "service #{service.inspect}" unless service.nil?
    service = DisplayObject.get_service_from_request(request) unless request.miq_request_tasks.first.nil?
    service ? DisplayObject.inspect_service(service, true) : DisplayObject.log_request_info(request)
  end

  def self.display_active_requests
    prov = MiqProvision.new(:userid => User.first.userid)
    requests = prov.quota_find_active_prov_request({})
    log_active_requests(requests)

    x = prov.quota_provision_stats(:quota_find_active_prov_request, {})
    puts "Total active resources: #{x.inspect}"
  end

  def self.log_active_requests(requests)
    puts "  Active Provisionin Requests"
    puts "---------------------------------------------------------------"
    requests.sort_by(&:id).each do |r|
      puts "  ID: <#{r.id}> Type: #{r.type} Created: #{r.created_on} Status: <#{r.status}> State: <#{r.request_state}>"
    end
    puts "---------------------------------------------------------------"
    puts "Total active requests: #{requests.count}"
  end
end

namespace :display do
  namespace :object do
    desc 'Inspect a Service.'
    task :inspect_service => :environment do
      raise 'Must specify a Service ID' if ENV['SERVICE_ID'].blank?
      DisplayObject.inspect_service(Service.find(ENV['SERVICE_ID']), true)
    end

    desc 'Inspect a Request'
    task :inspect_request => :environment do
      raise 'Must specify a Request ID' if ENV['REQUEST_ID'].blank?
      DisplayObject.inspect_request(MiqRequest.find(ENV['REQUEST_ID']))
    end

    desc 'Display active provisioning requests'
    task :display_active_requests => :environment do
      DisplayObject.display_active_requests
    end
  end
end
