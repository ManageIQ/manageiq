require 'fog/openstack'

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
  $stderr.puts("Usage: bundle exec rails r spec/tools/environment_builders/openstack_install_environments.rb --install")
  $stderr.puts("- installs OpenStack on servers using packstack")
  $stderr.puts("Usage: bundle exec rails r spec/tools/environment_builders/openstack_install_environments.rb --activate_paginations")
  $stderr.puts("- activate paginations for OpenStack on servers")
  $stderr.puts("Usage: bundle exec rails r spec/tools/environment_builders/openstack_install_environments.rb --deactivate_paginations")
  $stderr.puts("- deactivate paginations for OpenStack on servers")
  $stderr.puts("Filter one with --only-environment")
  $stderr.puts("Options:")
  $stderr.puts("         [--only-environment <name>]  - allowed values #{allowed_environments}")
  exit(2)
end

unless File.exist?(openstack_environment_file)
  raise ArgumentError, usage("expecting #{openstack_environment_file}")
end

@only_environment = nil

loop do
  option = ARGV.shift
  case option
  when '--only-environment', '-o'
    argv      = ARGV.shift
    supported = allowed_environments
    raise ArgumentError, usage("supported --identity options are #{supported}") unless supported.include?(argv.to_sym)
    @only_environment = argv.to_sym
  when '--activate-paginations', '--deactivate-paginations', '--install'
    @method = option
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

    @environment = env_name.to_sym

    unless @only_environment.blank?
      puts "Skipping enviroment #{@environment}"
      next unless @environment == @only_environment
    end

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

    unless @only_environment.blank?
      puts "Skipping enviroment #{@environment}"
      next unless @environment == @only_environment
    end

    stackrc_name = 'keystonerc_admin'
    stackrc_name += '_v3' if identity_service == :v3

    puts "Obtaining credentials of installed OpenStack #{env_name}"
    cmd     = "ssh #{ssh_user}@#{env["ip"]} 'cat #{stackrc_name}'"
    puts stackrc = ` #{cmd} `

    env["password"] = stackrc.match(/OS_PASSWORD=(.*?)$/)[1]
    env["user"]     = stackrc.match(/OS_USERNAME=(.*?)$/)[1]
  end

  puts "---------------------------------------------------------------------------------------------------------------"
  puts "Updating #{openstack_environment_file} with OpenStack credentials"
  File.open(openstack_environment_file, 'w') { |f| f.write openstack_environments.to_yaml }
end

def activate_paginations
  openstack_environments.each do |env|
    env_name     = env.keys.first
    env          = env[env_name]
    ssh_user     = env["ssh_user"] || "root"

    @environment = env_name.to_sym

    unless @only_environment.blank?
      puts "Skipping enviroment #{@environment}"
      next unless @environment == @only_environment
    end

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

    unless @only_environment.blank?
      puts "Skipping enviroment #{@environment}"
      next unless @environment == @only_environment
    end

    puts "-------------------------------------------------------------------------------------------------------------"
    case @environment
    when :grizzly
      puts " We don't support pagination for grizzly"
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

case @method
when "--install"
  install_environments
when "--activate-paginations"
  activate_paginations
when "--deactivate-paginations"
  deactivate_paginations
end
