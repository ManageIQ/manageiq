require 'fog'
# TODO(lsmola) how do I load this?
# require 'models/ems_refresh/refreshers/openstack/refresh_spec_environments'

$LOAD_PATH.push(Rails.root.to_s)
require_relative 'openstack/interaction_methods'

require_relative 'openstack/services/identity/builder'
require_relative 'openstack/services/network/builder'
require_relative 'openstack/services/compute/builder'
require_relative 'openstack/services/volume/builder'
require_relative 'openstack/services/image/builder'

include Openstack::InteractionMethods

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Usage: bundle exec rails rspec/tools/environment_builders/openstack_environments.rb --load")
  $stderr.puts("- loads credentials for enviroments.yaml to all redresh tests and VCRs")
  $stderr.puts("Usage: bundle exec rails rspec/tools/environment_builders/openstack_environments.rb --obfuscate")
  $stderr.puts("- obfuscates all credentials in tests and VCRs")
  exit(2)
end

@method = ARGV.shift
raise ArgumentError, usage("expecting method name as first argument") unless %w(--load --obfuscate).include?(@method)

OBFUSCATED_PASSWORD = "password"
OBFUSCATED_IP = "1.2.3.4"

def load_environments
  openstack_environments.each do |env|
    env_name = env.keys.first
    env      = env[env_name]

    file_name = File.join(test_base_dir, "openstack_refresher_rhos_#{env_name}_spec.rb")
    change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])

    file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
    change_file(file_name, OBFUSCATED_PASSWORD, env["password"], OBFUSCATED_IP, env["ip"])
  end
end

def obfuscate_environments
  openstack_environments.each do |env|
    env_name = env.keys.first
    env      = env[env_name]

    file_name = File.join(test_base_dir, "openstack_refresher_rhos_#{env_name}_spec.rb")
    change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)

    file_name = File.join(vcr_base_dir, "refresher_rhos_#{env_name}.yml")
    change_file(file_name, env["password"], OBFUSCATED_PASSWORD, env["ip"], OBFUSCATED_IP)
  end
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

def base_dir
  Rails.root.to_s
end

def vcr_base_dir
  File.join(base_dir, 'spec/vcr_cassettes/manageiq/providers/openstack/cloud_manager')
end

def test_base_dir
  File.join(base_dir, 'spec/models/ems_refresh/refreshers')
end

def openstack_environments
  YAML.load_file(File.join(base_dir, "openstack_environments.yml"))
end

case @method
  when "--load"
    load_environments
  when "--obfuscate"
    obfuscate_environments
end
