
namespace :config do
  role_list = ["automate", "database_owner", "ems_metrics_coordinator", "ems_metrics_collector", "ems_metrics_processor", "database_operations", "event", "git_owner", "notifier", "ems_inventory", "ems_operations", "rhn_mirror", "reporting", "scheduler", "smartproxy", "smartstate", "user_interface", "web_services", "websocket"]

  desc "Usage information regarding available tasks"
  task :usage do
    puts "The following configuration tasks are available, arguments between [] are optional:"
    puts " List all roles available           - Usage: rake config:list_roles"
    puts " List appliance active roles        - Usage: rake config:list_active_roles [APPLIANCE_ID=appliance_id]"
    puts " Set appliance roles                - Usage: rake config:set_roles SERVER_ROLES='[\"roles\", \"json\", \"array\"]' [APPLIANCE_ID=appliance_id]"
    puts " Summary                            - Usage: rake config:summary"
    puts " Create zone                        - Usage: rake config:create_zone NAME=zone_name DESCRIPTION=zone_description"
    puts " Modify zone                        - Usage: rake config:modify_zone APPLIANCE_ID=appliance_id ZONE_NAME=zone_name"
    puts " List appliances                    - Usage: rake config:list_appliances"
    puts " List zones                         - Usage: rake config:list_zones"
  end

  desc "List all roles available"
  task :list_roles  do
    puts role_list.to_json
  end

  desc "List appliance active roles"
  task :list_active_roles => [:environment] do
    unless ENV['APPLIANCE_ID'].blank?
      puts MiqServer.find(ENV['APPLIANCE_ID']).role.split(",").to_json
    else
      puts MiqServer.my_server.active_role_names.to_json
    end
  end

  desc "Set appliance roles"
  task :set_roles => [:environment] do
    begin
      raise "You must specify a valid list of server foles" if ENV['SERVER_ROLES'].blank?
      server_roles = JSON.parse(ENV['SERVER_ROLES'])
      server_roles.each do |role|
        raise "Role #{role} not available" if not role_list.include? role
      end
      unless ENV['APPLIANCE_ID'].blank?
        MiqServer.find(ENV['APPLIANCE_ID']).set_config(:server => {:role => server_roles.join(",")})
      else
        MiqServer.my_server.set_config(:server => {:role => server_roles.join(",")})
      end
    rescue => err
      STDERR.puts err.message
      exit(1)
    end
  end

  desc "Get appliance config summary"
  task :summary => [:environment] do
    puts "Appliance name: #{MiqServer.my_server.name}"
    puts "Region number: #{MiqServer.my_server.region_number}"
    puts "Region: #{MiqServer.my_server.region_description}"
    puts "Zone ID: #{MiqServer.my_server.zone_id}"
    puts "Zone: #{MiqServer.my_server.zone_description}"
    puts "Active roles: #{MiqServer.my_server.active_role}"
  end

  desc "Create zone"
  task :create_zone => [:environment] do
    begin
      raise "You must specify zone name and zone description" if ENV['NAME'].blank? or ENV['DESCRIPTION'].blank?
      zone = Zone.new({'name' => ENV['NAME'], 'description' => ENV['DESCRIPTION']})
      zone.save
    rescue => err
      STDERR.puts err.message
      exit(1)
    end
  end

  desc "Modify appliance zone"
  task :modify_zone => [:environment] do
    begin
      raise "You must specify a existent zone name and appliance name" if ENV['APPLIANCE_ID'].blank? or ENV['ZONE_NAME'].blank?
      appliance = MiqServer.find(ENV['APPLIANCE_ID'])
      zone = Zone.find_by_name(ENV['ZONE_NAME'])
      if zone.nil? or appliance.nil?
        raise "Zone or appliance not found"
      end
      appliance.zone = zone
      appliance.save
      config = VMDB::Config.new("vmdb")
      config.config[:server][:zone] = ENV['ZONE_NAME']
      config.validate
      config.save
    rescue => err
      STDERR.puts err.message
      exit(1)
    end
  end

  desc "List available appliances"
  task :list_appliances=> [:environment] do
    arr = []
    MiqServer.all.as_json.each do |s|
      arr << s.slice("id", "name")
    end
    puts arr.to_json
  end

  desc "List available zones"
  task :list_zones=> [:environment] do
    arr = []
    Zone.all.as_json.each do |s|
      arr << s.slice("name", "id")
    end
    puts arr.to_json
  end

end
