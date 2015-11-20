require 'fog'
# TODO(lsmola) how do I load this?
# require 'models/ems_refresh/refreshers/openstack/refresh_spec_environments'

$LOAD_PATH.push(Rails.root.to_s)
require_relative 'openstack/helper_methods'

include Openstack::HelperMethods

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Usage: bundle exec rails rspec/tools/environment_builders/openstack_environments.rb --load")
  $stderr.puts("- loads credentials for enviroments.yaml to all refresh tests and VCRs")
  $stderr.puts("Usage: bundle exec rails rspec/tools/environment_builders/openstack_environments.rb --obfuscate")
  $stderr.puts("- obfuscates all credentials in tests and VCRs")
  exit(2)
end

@method = ARGV.shift
unless %w(--load --obfuscate --activate-paginations --deactivate-paginations).include?(@method)
  raise ArgumentError, usage("expecting method name as first argument")
end

OBFUSCATED_PASSWORD = "password_2WpEraURh"
OBFUSCATED_IP = "1.2.3.4"
OBFUSCATED_DATE = "Fri, 20 Nov 2015 08:24:54 GMT"
OBFUSCATED_X_AUTH_TOKEN = "49ab69a55ee24d4283c8a229e4c11541"
OBFUSCATED_REQUEST_ID = "req-8bcce180-cfff-433e-bae0-95ba29666425"
OBFUSCATED_TRANS_ID = "txaac826f4cca84bfab931b-00564f33be"
OBFUSCATED_TIMESTAMP = "1448025167.35155"
OBFUSCATED_AUDIT_IDS = ["bobuzZI8S2e7H0w0Ydi0XQ"]

def load_environments
  openstack_environments.each do |env|
    env_name = env.keys.first
    env      = env[env_name]

    puts "-------------------------------------------------------------------------------------------------------------"
    puts "Loading enviroment credentials for #{env_name}"
    file_name = File.join(test_base_dir, "refresher_rhos_#{env_name}_spec.rb")
    change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

    file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
    change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])
  end
end

def obfuscate_environments
  openstack_environments.each do |env|
    env_name = env.keys.first
    env      = env[env_name]

    puts "-------------------------------------------------------------------------------------------------------------"
    puts "Obfuscating enviroment credentials for #{env_name}"
    file_name = File.join(test_base_dir, "refresher_rhos_#{env_name}_spec.rb")
    change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

    vcr_env_file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
    change_file(vcr_env_file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

    change_variable_atributes(vcr_env_file_name)
  end

  # Do the change of attributes also for Infra env
  puts "-------------------------------------------------------------------------------------------------------------"
  puts "Obfuscating VCR env refresher_rhos_juno.yml"
  change_variable_atributes(File.join(vcr_base_dir_infra, 'refresher_rhos_juno.yml'))
end

def activate_paginations
  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    @environment = env_name.to_sym

    case @environment
    when :grizzly
      puts " We don't support pagination for grizzly"
      next
    when :havana
      file = "openstack-activate-pagination-rhel6"
    else
      file = "openstack-activate-pagination"
    end

    puts "-------------------------------------------------------------------------------------------------------------"
    puts "Activate paginations in installed OpenStack #{env_name}"
    cmd = " ssh #{ssh_user}@#{env["ip"]} "\
          " 'curl http://file.brq.redhat.com/~lsmola/miq/#{file} | bash -x' "
    puts cmd
    ` #{cmd} `
  end
end

def deactivate_paginations
  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    @environment = env_name.to_sym

    puts "-------------------------------------------------------------------------------------------------------------"
    case @environment
    when :grizzly
      puts "We don't support pagination for grizzly"
      next
    when :havana
      file = "openstack-deactivate-pagination-rhel6"
    else
      file = "openstack-deactivate-pagination"
    end

    puts "Deactivate paginations in installed OpenStack #{env_name}"
    cmd = " ssh #{ssh_user}@#{env["ip"]} "\
          " 'curl http://file.brq.redhat.com/~lsmola/miq/#{file} | bash -x' "
    puts cmd
    ` #{cmd} `
  end
end

def change_variable_atributes(vcr_env_file_name)
  # Set all dates, tokens, etc. to one value, so we don't have diff in every rebuilt VCR and therefore git conflict.
  # Without this, each 2 VCRs would have git conflict, even when no API request changed,
  vcr_env = YAML.load_file(vcr_env_file_name)
  vcr_env["http_interactions"].each do |request|
    request["request"]["headers"]["User-Agent"] = "fog/2.0.0.pre.0"
    request["request"]["headers"]["X-Auth-Token"] = OBFUSCATED_X_AUTH_TOKEN
    request["response"]["headers"]["Date"] = OBFUSCATED_DATE
    unless (response_header = request.fetch_path("response", "headers")).blank?
      response_header["X-Compute-Request-Id"] = OBFUSCATED_REQUEST_ID if response_header["X-Compute-Request-Id"]
      response_header["X-Openstack-Request-Id"] = OBFUSCATED_REQUEST_ID if response_header["X-Openstack-Request-Id"]
      response_header["X-Timestamp"] = OBFUSCATED_TIMESTAMP if response_header["X-Timestamp"]
      response_header["X-Put-Timestamp"] = OBFUSCATED_TIMESTAMP if response_header["X-Put-Timestamp"]
      response_header["X-Trans-Id"] = OBFUSCATED_TRANS_ID if response_header["X-Trans-Id"]
      response_header["X-Subject-Token"] = OBFUSCATED_X_AUTH_TOKEN if response_header["X-Subject-Token"]
    end

    request["recorded_at"] = OBFUSCATED_DATE
    request["response"]["http_version"] = ""

    proces_request_body!(request)
    proces_response_body!(request)
  end
  File.open(vcr_env_file_name, 'w') { |f| f.write vcr_env.to_yaml }
end

def proces_request_body!(request)
  begin
    body = JSON.parse(request["request"]["body"]["string"])
  rescue
    # Skip no valid JSONs, e.g when 404 is returned
    return
  end
  return if body.blank? || !body.kind_of?(Hash)
  body["auth"]["token"]["id"] = OBFUSCATED_X_AUTH_TOKEN if body.fetch_path("auth","token","id")

  request["request"]["body"]["string"] = JSON.dump(body)
end

def proces_response_body!(request)
  begin
    body = JSON.parse(request["response"]["body"]["string"])
  rescue
    puts "Failed to parse request: #{request["response"]["body"]["string"]}"
    return
  end
  return if body.blank? || !body.kind_of?(Hash)
  # Do not mess with sec groups order
  return unless body['security_groups'].blank? # TODO(lsmola) I will need to sort this

  token = body.fetch_path("access","token")
  process_token(token) unless token.blank?

  # Keystone v3 token
  process_token(body["token"]) unless body["token"].blank?

  unless body["availabilityZoneInfo"].blank?
    body["availabilityZoneInfo"].each do |a_zone|
      a_zone["hosts"].each_pair do |_host_name, host|
        host.each_pair do |_service_name, service|
          service['updated_at'] = OBFUSCATED_DATE
        end
      end
    end
  end

  # Gah heat contains randomly sorted element in the response,
  unless body["resources"].blank?
    body["resources"].each do |resource|
      if !resource.blank? && resource.kind_of?(Hash) && !resource["required_by"].blank?
        resource["required_by"] = resource["required_by"].sort
      end
    end
  end

  unless body["nodes"].blank?
    body["nodes"].each do |node|
      node['updated_at'] = OBFUSCATED_DATE unless node['updated_at'].blank?
    end
  end

  request["response"]["body"]["string"] = JSON.dump(body)
end

def process_token(token)
  token["issued_at"]  = OBFUSCATED_DATE         if token["issued_at"]
  token["expires"]    = OBFUSCATED_DATE         if token["expires"]
  token["expires_at"] = OBFUSCATED_DATE         if token["expires_at"]
  token["id"]         = OBFUSCATED_X_AUTH_TOKEN if token["id"]
  token["audit_ids"]  = OBFUSCATED_AUDIT_IDS    if token["audit_ids"]
end

def change_file(file_name, from_password, to_password, from_ip, to_ip)
  return unless File.exist?(file_name)

  file = File.read(file_name)
  file.gsub!(from_password, to_password)
  file.gsub!(from_ip, to_ip)

  File.open(file_name, 'w') do |out|
    out << file
  end
end

case @method
when "--load"
  load_environments
when "--obfuscate"
  obfuscate_environments
when "--activate-paginations"
  activate_paginations
when "--deactivate-paginations"
  deactivate_paginations
end
