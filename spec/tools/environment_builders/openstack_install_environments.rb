require 'fog'

$LOAD_PATH.push(Rails.root.to_s)
require_relative 'openstack/interaction_methods'
require_relative 'openstack/helper_methods'
include Openstack::InteractionMethods
include Openstack::HelperMethods

require "#{test_base_dir}/refresh_spec_environments"
include Openstack::RefreshSpecEnvironments

require_relative 'openstack/services/identity/builder'
require_relative 'openstack/services/network/builder'
require_relative 'openstack/services/compute/builder'
require_relative 'openstack/services/volume/builder'
require_relative 'openstack/services/image/builder'
require_relative 'openstack/services/orchestration/builder'

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Installs OpenStack on servers using packstack")
  $stderr.puts("Filter one with --only-environment")
  $stderr.puts("Options:")
  $stderr.puts("         [--only-envinronment <name>]  - allowed values #{allowed_enviroments}")
  exit(2)
end

unless File.exist?("openstack_environments.yml")
  raise ArgumentError, usage("expecting openstack_environments.yml in ManageIQ root dir")
end

@only_environment = nil

loop do
  option = ARGV.shift
  case option
  when '--only-environment', '-o'
    argv      = ARGV.shift
    supported = allowed_enviroments
    raise ArgumentError, usage("supported --identity options are #{supported}") unless supported.include?(argv.to_sym)
    @only_environment = argv.to_sym
  when /^-/
    usage("Unknown option: #{option}")
  else
    break
  end
end

def install_environments
  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    cmd = "ssh-copy-id #{ssh_user}@#{env["ip"]}"
    puts "Executing: #{cmd}"
    ` #{cmd} `
  end

  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    @environment = env_name.to_sym

    unless @only_environment.blank?
      puts "Skipping enviroment #{@environment}"
      next unless @environment == @only_environment
    end

    cmd = ""
    case @environment
    when :grizzly
      cmd += "ssh #{ssh_user}@#{env["ip"]}"\
             " 'curl http://file.brq.redhat.com/~mcornea/miq/openstack/openstack-install-grizzly | bash -x' "
    when :havana
      cmd += "ssh #{ssh_user}@#{env["ip"]}"\
             " 'curl http://file.brq.redhat.com/~mcornea/miq/openstack/openstack-install-havana | bash -x' "
    else
      cmd += "ssh #{ssh_user}@#{env["ip"]}"\
             " 'curl http://file.brq.redhat.com/~mcornea/miq/openstack/openstack-install > openstack-install; "\
             "  chmod 755 openstack-install; "\
             "  ./openstack-install #{environment_release_number} #{networking_service} #{identity_service};' "
    end

    puts "Executing: #{cmd}"
    puts ` #{cmd} `
  end

  puts "---------------------------------------------------------------------------------------------------------------"
  puts "------------------------------------------- instalation finished ----------------------------------------------"

  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    @environment = env_name.to_sym

    stackrc_name = 'keystonerc_admin'
    stackrc_name += '_v3' if identity_service == :v3

    puts "Obtaining credentials of installed OpenStack #{env_name}"
    cmd     = "ssh #{ssh_user}@#{env["ip"]} 'cat #{stackrc_name}'"
    puts stackrc = ` #{cmd} `

    env["password"] = stackrc.match(/OS_PASSWORD=(.*?)$/)[1]
    env["user"]     = stackrc.match(/OS_USERNAME=(.*?)$/)[1]
  end

  puts "---------------------------------------------------------------------------------------------------------------"
  puts "Updating openstack_environments.yml with OpenStack credentials"
  File.open(openstack_environment_file, 'w') { |f| f.write openstack_environments.to_yaml }
end

install_environments
