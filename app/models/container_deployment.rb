class ContainerDeployment < ApplicationRecord
  has_many :deployment_authentication
  belongs_to :deployed_ext_management_system, :class_name => 'ExtManagementSystem'
  belongs_to :deployed_on_ext_management_system, :class_name => 'ExtManagementSystem'
  belongs_to :miq_request_task
  has_many :container_deployment_nodes

  DEPLOYMENT_TYPES = ['OpenShift Origin', 'OpenShift Enterprise', 'Atomic Enterprise'].freeze

  def self.supported_types
    DEPLOYMENT_TYPES
  end

  def masters
    container_deployment_nodes.find_tagged_with(:any => "/user/master", :ns => "*")
  end

  def deployment_master
    container_deployment_nodes.find_tagged_with(:any => "/user/deployment_master", :ns => "*").first
  end

  def nodes
    container_deployment_nodes.find_tagged_with(:any => "/user/node", :ns => "*")
  end

  def nfs_ips_or_hostnames
    to_ip_or_hostname_array container_deployment_nodes.find_tagged_with(:any => "/user/nfs", :ns => "*")
  end

  def masters_ips_or_hostnames
    to_ip_or_hostname_array masters
  end

  def deployment_master_ips_or_hostnames
    extract_public_ip_or_hostname deployment_master
  end

  def nodes_ips_or_hostnames
    to_ip_or_hostname_array(nodes, true)
  end

  def to_ip_or_hostname_array(container_deployment_nodes, add_labels = false)
    ip_array = []
    container_deployment_nodes.each do |container_deployment_node|
      ip_array << if container_deployment_node.vm
                    container_deployment_node.vm.hardware.ipaddresses.last + (!container_deployment_node.labels.empty? && add_labels ? " openshift_node_labels=#{container_deployment_node.labels}" : "")
                  elsif container_deployment_node.ip_or_hostname
                    container_deployment_node.ip_or_hostname + (!container_deployment_node.labels.empty? && add_labels ? " openshift_node_labels=#{container_deployment_node.labels}" : "")
                  end
    end
    ip_array
  end

  def add_deployment_provider(options)
    provider = ExtManagementSystem.new(
      :type      => options[:provider_type],
      :name      => options[:provider_name],
      :port      => options[:provider_port],
      :hostname  => options[:provider_hostname],
      :ipaddress => options[:provider_ipaddress])
    provider.save!
    provider.update_authentication(:bearer => {:auth_key => options[:auth_key], :save => true})
    valid_provider = provider.authentication_check.first
    if valid_provider
      self.deployed_ext_management_system = provider
      save!
    else
      provider.destroy
    end
    valid_provider
  end

  def assign_container_deployment_node(options)
    send(options[:type]).each do |deploymnet_node|
      next unless deploymnet_node.vm.nil?
      deploymnet_node.vm = Vm.find(options[:vm_id])
      deploymnet_node.save!
    end
  end

  def generate_ansible_inventory_for_subscription
    template = <<eos
[OSEv3:children]
masters
nodes
[OSEv3:vars]
ansible_ssh_user=#{ssh_user}
deployment_type=openshift-enterprise
rhsub_user=#{rhsm_user}
rhsub_pass=#{rhsm_pass}
rhsub_pool=#{rhsm_sku}
[masters]
#{masters_ips_or_hostnames.join("\n") unless masters.empty?}
[nodes]
#{nodes_ips_or_hostnames.join("\n") unless nodes.empty?}
eos
    template
  end

  def generate_ansible_inventory
    template = <<eos
[OSEv3:vars]
#{deployment_authentication.first.generate_ansible_entry}
#{"containerized=true" if containerized}
[OSEv3:children]
masters
nodes
[masters:vars]
ansible_ssh_user=#{ssh_user}
ansible_sudo=true
deployment_type=#{deployment_type}
#openshift_use_manageiq=True
[nodes:vars]
ansible_ssh_user=#{ssh_user}
ansible_sudo=true
deployment_type=#{deployment_type}
#openshift_use_manageiq=True
#{add_nfs unless nfs_ips_or_hostnames.empty?}
[masters]
#{(deployment_master_ips_or_hostnames.to_s + " ansible_connection=local openshift_scheduleable=True") unless deployment_master_ips_or_hostnames.nil?}
    #{masters_ips_or_hostnames.join("\n") unless masters.empty?}
[nodes]
#{nodes_ips_or_hostnames.join("\n") unless nodes.empty?}
eos
    template
  end

  def replace_connecting_master_ip(nodes, master_ip)
    nodes.each_with_index do |node, index|
      if node.include? master_ip
        nodes[index] = "#{master_ip}              ansible_connection=local"
      end
    end
    nodes
  end

  def extract_public_ip_or_hostname(deployment_node)
    return deployment_node.ip_or_hostname if deployment_node.ip_or_hostname
    return "" if deployment_method.include? "managed_provision"

    vm = deployment_node.vm
    hostname = vm.hostnames
    if hostname.empty?
      ips = vm.hardware.ipaddresses
      ips.each do |ip|
        return ip if public_ip? ip
      end
    end
    hostname.first || ips.last
  end

  def public_ip?(ip)
    require "ipaddr"
    private = false
    ip_addr = IPAddr.new(ip).to_i
    ranges = ['10.0.0.0|10.255.255.255',
              '172.16.0.0|172.31.255.255',
              '192.168.0.0|192.168.255.255',
              '169.254.0.0|169.254.255.255',
              '127.0.0.0|127.255.255.255']
    ranges.each do |range|
      low, high = range.split("|")
      low = IPAddr.new(low).to_i
      high = IPAddr.new(high).to_i
      private = true if (low..high).cover? ip_addr
    end
    return ip unless private
  end

  def self.add_basic_root_template
    unless CustomizationTemplate.find_by_name("Basic root pass template")
      options = {:name              => "Basic root pass template",
                 :description       => "This template takes use of rootpassword defined in the UI",
                 :script            => "#cloud-config\nchpasswd:\n  list: |\n    root:<%= MiqPassword.decrypt(evm[:root_password]) %>\n  expire: False",
                 :type              => "CustomizationTemplateCloudInit",
                 :system            => true,
                 :pxe_image_type_id => PxeImageType.first.id}
      CustomizationTemplate.new(options).save
    end
  end

  def generate_automation_params(params)
    parameters = { # for all
      :deployment_type          => deployment_type,
      :deployment_method        => deployment_method,
      :ssh_private_key          => [ssh_private],
      :ssh_username             => ssh_user,
      :inventory                => generate_ansible_inventory,
      :rhel_subscribe_inventory => generate_ansible_inventory_for_subscription
    }
    if deployment_method.include? "managed_provision"
      parameters_provision = { # provision
        :masters_provision => {
          :number_of_vms  => params["num_of_masters"],
          :templateFields => {
            "guid" => VmOrTemplate.find(params["master_template_id"]).guid, "name" => VmOrTemplate.find(params["master_template_id"]).name
          },
          :vmFields       => vm_fields("masters", params),
          :requester      => {
            'owner_email'      => 'temp@temp.com',
            'owner_first_name' => 'temp',
            'owner_last_name'  => 'temp'
          },
          :tags           => nil,
          :ws_values      => {
            "ssh_public_key" => ssh_public
          }
        },
        :nodes_provision   => {
          :number_of_vms  => params["num_of_nodes"],
          :templateFields => {
            "guid" => VmOrTemplate.find(params["node_template_id"]).guid, "name" => VmOrTemplate.find(params["node_template_id"]).name
          },
          :vmFields       => vm_fields("nodes", params),
          :requester      => {
            'owner_email'      => 'temp@temp.com',
            'owner_first_name' => 'temp',
            'owner_last_name'  => 'temp'
          },
          :tags           => nil,
          :ws_values      => {
            "ssh_public_key" => ssh_public
          }
        },
        :ssh_public_key    => ssh_public
      }
      parameters.merge parameters_provision
    else
      parameters_existing = { # non-managed + managed-existing
        :deployment_master => deployment_master_ips_or_hostnames,
        :masters           => masters_ips_or_hostnames,
        :nodes             => nodes_ips_or_hostnames
      }
      parameters.merge parameters_existing
    end
  end

  def vm_fields(type, params)
    options = {}
    options["customization_template_id"] = CustomizationTemplate.find_by_name("Basic root pass template").id
    options[type + "_vm_name"] = params[type + "_base_name"]
    options[type + "_vm_memory"] = params[type + "_vm_memory"] if params[type + "_vm_memory"]
    options[type + "_cpu"] = params[type + "_cpu"] if params[type + "_cpu"]
    options[type + "_instance_type"] = params[type + "_instance_type"] if params[type + "_instance_type"]
    options
  end

  def generate_ssh_keys
    require 'sshkey'
    keys = SSHKey.generate
    self.ssh_public  = keys.public_key
    self.ssh_private = keys.private_key
  end

  def create_deployment_auth(options)
    deployment_authentication << DeploymentAuthentication.new(:name                                      => options[:auth_name],
                                                              :challenge                                 => options[:auth_challenge],
                                                              :login                                     => options[:auth_login],
                                                              :kind                                      => options[:auth_kind],
                                                              :htpassd_users                             => options[:auth_htpassd_users].to_json,
                                                              :ldap_id                                   => options[:auth_ldap_id],
                                                              :ldap_email                                => options[:auth_ldap_email],
                                                              :ldap_name                                 => options[:auth_ldap_name],
                                                              :ldap_preferred_user_name                  => options[:auth_ldap_preferred_user_name],
                                                              :ldap_bind_dn                              => options[:auth_ldap_bind_dn],
                                                              :ldap_bind_password                        => options[:auth_ldap_bind_password],
                                                              :ldap_ca                                   => options[:auth_ldap_ca],
                                                              :ldap_insecure                             => options[:auth_ldap_insecure],
                                                              :ldap_url                                  => options[:auth_ldap_url],
                                                              :request_header_challenge_url              => options[:auth_request_header_challenge_url],
                                                              :request_header_login_url                  => options[:auth_request_header_login_url],
                                                              :request_header_client_ca                  => options[:auth_request_header_client_ca],
                                                              :request_header_headers                    => options[:auth_request_header_headers],
                                                              :request_header_name_headers               => options[:auth_request_header_name_headers],
                                                              :request_header_preferred_username_headers => options[:auth_request_header_preferred_username_headers],
                                                              :request_header_email_headers              => options[:auth_request_header_email_headers],
                                                              :client_id                                 => options[:auth_client_id],
                                                              :client_secret                             => options[:auth_client_secret],
                                                              :open_id_ca                                => options[:auth_open_id_ca],
                                                              :open_id_extra_scopes                      => options[:auth_open_id_extra_scopes],
                                                              :open_id_extra_authorize_parameters        => options[:auth_open_id_extra_authorize_parameters],
                                                              :open_id_sub_claim                         => options[:auth_open_id_sub_claim],
                                                              :open_id_authorization_endpoint            => options[:auth_open_id_authorization_endpoint],
                                                              :open_id_token_endpoint                    => options[:auth_open_id_token_endpoint],
                                                              :open_id_extra_scopes                      => options[:open_id_extra_scopes],
                                                              :open_id_extra_authorize_parameters        => options[:open_id_extra_authorize_parameters],

                                                              :google_hosted_domain                      => options[:auth_google_hosted_domain],
                                                              :github_organizations                      => options[:auth_github_organizations])
    save!
  end

  def create_deployment_nodes(vm_groups, labels, tags, vm_id = nil, ip_or_hostname = nil)
    vm_groups.each_with_index do |vms, index|
      vms.each do |vm_attr|
        container_deployment_node = ContainerDeploymentNode.where((ip_or_hostname ? :ip_or_hostname : :vm_id) => vm_attr)
                                    .where(:container_deployment_id => id)
        if container_deployment_node.empty?
          container_deployment_node = ContainerDeploymentNode.new
          container_deployment_node.ip_or_hostname = vm_attr if ip_or_hostname
          container_deployment_node.vm = Vm.find(vm_attr) if vm_id
          container_deployment_nodes << container_deployment_node
        else
          container_deployment_node = container_deployment_node.first
        end
        container_deployment_node.labels = JSON.parse(labels[vm_attr].to_json).to_h if labels && labels[vm_attr]
        container_deployment_node.tag_add tags[index]
        container_deployment_node.save!
      end
    end
  end

  def add_nfs
    template = <<eos
[nfs]
#{nfs_ips_or_hostnames.join("\n")}
eos
    template
  end
end
