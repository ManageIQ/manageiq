class ContainerDeployment < ApplicationRecord
  belongs_to :deployed_ems, :class_name => 'ManageIQ::Providers::ContainerManager'
  belongs_to :deployed_on_ems, :class_name => 'ExtManagementSystem', :inverse_of => :container_deployments
  belongs_to :automation_task
  has_many :container_deployment_nodes, :dependent => :destroy
  has_many :container_volumes, :as => :parent
  has_many :custom_attributes, :as => :resource, :dependent => :destroy
  has_many :authentications, :as => :resource, :dependent => :destroy
  serialize :customizations, Hash
  AUTH_CONSTS = {"AuthenticationAllowAll" => AuthenticationAllowAll, "AuthenticationHtpasswd" => AuthenticationHtpasswd, "AuthenticationLdap" => AuthenticationLdap, "AuthenticationRequestHeader" => AuthenticationRequestHeader, "AuthenticationOpenId" => AuthenticationOpenId, "AuthenticationGoogle" => AuthenticationGoogle, "AuthenticationGithub" => AuthenticationGithub, "AuthPrivateKey" => AuthPrivateKey, "AuthenticationRhsm" => AuthenticationRhsm}.freeze
  AUTHENTICATIONS_NAMES = {"AuthenticationAllowAll" => "AllowAllPasswordIdentityProvider", "AuthenticationHtpasswd" => "HTPasswdPasswordIdentityProvider", "AuthenticationLdap" => "LDAPPasswordIdentityProvider", "AuthenticationRequestHeader" => "RequestHeaderIdentityProvider", "AuthenticationOpenId" => "OpenIDIdentityProvider", "AuthenticationGoogle" => "GoogleIdentityProvider", "AuthenticationGithub" => "GitHubIdentityProvider", "AuthPrivateKey" => "ssh", "AuthenticationRhsm" => "rhsm"}.freeze
  ANSIBLE_CONFIG_LOCATION = "/usr/share/atomic-openshift-utils/ansible.cfg".freeze

  def ssh_auth
    authentications.where(:type => "AuthPrivateKey").first
  end

  def rhsm_auth
    authentications.where(:type => "AuthenticationRhsm").first
  end

  def identity_provider_auth
    authentications.where.not(:type => "AuthPrivateKey").where.not(:type => "AuthenticationRhsm")
  end

  def roles_addresses(role)
    unless role.include? "deployment_master"
      addresses_array container_nodes_by_role(role)
    else
      extract_public_ip_or_hostname container_nodes_by_role(role).first
    end
  end

  def container_nodes_by_role(role)
    container_deployment_nodes.find_tagged_with(:any => "/user/#{role}", :ns => "*")
  end

  def num_of_nodes
    num = 0
    nodes = container_deployment_nodes.find_tagged_with(:any => "/user/node", :ns => "*")
    (nodes.select do |node| !node.is_tagged_with?("/master") end).count
  end

  # will be removed once moving to yaml format, no need to review method
  def addresses_array(container_deployment_nodes, add_labels = false)
    ip_array = []
    container_deployment_nodes.each do |container_deployment_node|
      ip_array << if container_deployment_node.vm
                    container_deployment_node.vm.hardware.ipaddresses.last + (!container_deployment_node.labels.empty? && add_labels ? " openshift_node_labels=#{container_deployment_node.labels}" : "")
                  elsif container_deployment_node.address
                    container_deployment_node.address + (!container_deployment_node.labels.empty? && add_labels ? " openshift_node_labels=#{container_deployment_node.labels}" : "")
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
      self.deployed_ems = provider
      save!
    else
      provider.destroy
    end
    valid_provider
  end

  # will be removed once moving to yaml format, no need to review method
  def generate_ansible_inventory_for_subscription
    template = <<eos
[OSEv3:children]
masters
nodes

[OSEv3:vars]
ansible_ssh_user=#{ssh_auth.userid}
deployment_type=openshift-enterprise
rhsub_user=#{rhsm_auth.rhsm_user}
rhsub_pass=#{rhsm_auth.password_encrypted}
rhsub_pool=#{rhsm_auth.rhsm_sku}

[masters]
#{(roles_addresses("master") - [roles_addresses("deployment_master")]).join("\n") unless (roles_addresses("master") - [roles_addresses("deployment_master")]).empty?}

[nodes]
#{(roles_addresses("node") - [roles_addresses("deployment_master")]).join("\n") unless roles_addresses("node").empty?}
eos
    template
  end

  # will be removed once moving to yaml format, no need to review method
  def generate_ansible_inventory
    template = <<eos
[OSEv3:vars]
#{identity_provider_auth.first.generate_ansible_entry}
    #{"containerized=true" if containerized}
[OSEv3:children]
masters
nodes

[masters:vars]
ansible_ssh_user=#{ssh_auth.userid}
ansible_sudo=true
deployment_type=#{kind}
#openshift_use_manageiq=True

[nodes:vars]
ansible_ssh_user=#{ssh_auth.userid}
ansible_sudo=true
deployment_type=#{kind}
#openshift_use_manageiq=True
#{add_role("nfs") unless roles_addresses("nfs").empty?}

[masters]
#{(roles_addresses("deployment_master").to_s + " ansible_connection=local openshift_scheduleable=True") unless roles_addresses("deployment_master").nil?}
#{roles_addresses("master").join("\n") unless (roles_addresses("master") - [roles_addresses("deployment_master")]).empty?}
[nodes]
#{roles_addresses("node").join("\n") unless (roles_addresses("node") - [roles_addresses("deployment_master")]).empty?}

eos
    template
  end

  def generate_ansible_yaml
    hash = {}
    hash[:version] = version
    hash[:deployment] = {}
    hash[:deployment][:ansible_config] = ANSIBLE_CONFIG_LOCATION
    hash[:deployment][:ansible_ssh_user] = ssh_auth.userid
    hash[:deployment][:hosts] = container_deployment_nodes.collect(&:ansible_config_format)
    hash[:deployment][:roles] = {}
    hash[:deployment][:roles][:master] = {}
    hash[:deployment][:roles][:master][:openshift_master_identity_providers] = []
    hash[:deployment][:roles][:master][:openshift_master_identity_providers] << identity_provider_auth.first.send(:ansible_config_format)
    unless identity_provider_auth.first.htpassd_users.empty?
      hash[:deployment][:roles][:master][:openshift_master_htpasswd_users] = {}
      hash[:deployment][:roles][:master][:openshift_master_htpasswd_users] = identity_provider_auth.first.htpassd_users
    end
    hash
  end

  def extract_public_ip_or_hostname(deployment_node)
    return deployment_node.address if deployment_node.vm_id.nil?
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
    unless CustomizationTemplate.find_by_name("SSH addition template")
      options = {:name              => "SSH addition template",
                 :description       => "This template takes use of rootpassword defined in the UI",
                 :script            => "#cloud-config\nusers:\n  - name: root\n    ssh-authorized-keys:\n      - <%= evm[:ws_values][:ssh_public_key] %>",
                 :type              => "CustomizationTemplateCloudInit",
                 :system            => true,
                 :pxe_image_type_id => PxeImageType.first.id}
      CustomizationTemplate.new(options).save
    end
  end

  def generate_automation_params(params)
    parameters = { # for all
      :deployment_type          => kind.to_s,
      :deployment_method        => method_type,
      :deployment_id            => id,
      :provider_name            => params["provider_name"],
      :ssh_private_key          => ssh_auth.auth_key_encrypted.to_s,
      :ssh_username             => ssh_auth.userid,
      :containerized            => containerized,
      :rhsub_user               => rhsm_auth.rhsm_user,
      :rhsub_pass               => rhsm_auth.password_encrypted,
      :rhsub_sku                => rhsm_auth.rhsm_sku
    }
    if method_type.include? "provision"
      parameters_provision = {
        :ssh_public_key        => ssh_auth.public_key,
        :provision_provider_id => deployed_on_ems.id,
        :masters_provision     => {
          :number_of_vms  => container_nodes_by_role("master").count,
          :templateFields => {
            "guid" => VmOrTemplate.find(params["masters_creation_template_id"]).guid, "name" => VmOrTemplate.find(params["masters_creation_template_id"]).name
          },
          :vmFields       => vm_fields("masters", params),
          :requester      => {
            'owner_email'      => 'temp@temp.com',
            'owner_first_name' => 'temp',
            'owner_last_name'  => 'temp'
          },
          :tags           => nil,
          :ws_values      => {
            "ssh_public_key" => ssh_auth.public_key
          }
        },
        :nodes_provision       => {
          :number_of_vms  => num_of_nodes,
          :templateFields => {
            "guid" => VmOrTemplate.find(params["nodes_creation_template_id"]).guid, "name" => VmOrTemplate.find(params["nodes_creation_template_id"]).name
          },
          :vmFields       => vm_fields("nodes", params),
          :requester      => {
            'owner_email'      => 'temp@temp.com',
            'owner_first_name' => 'temp',
            'owner_last_name'  => 'temp'
          },
          :tags           => nil,
          :ws_values      => {
            "ssh_public_key" => ssh_auth.public_key
          }
        },
      }
      parameters.merge parameters_provision
    else
      parameters_existing = { # non-managed + managed-existing
        :deployment_master        => roles_addresses("deployment_master"),
        :masters                  => roles_addresses("master"),
        :nodes                    => roles_addresses("node"),
        :inventory                => generate_ansible_inventory,
        :rhel_subscribe_inventory => generate_ansible_inventory_for_subscription,
      }
      parameters.merge parameters_existing
    end
  end

  def vm_fields(type, params)
    options = {}
    options["customization_template_id"] = CustomizationTemplate.find_by_name("SSH addition template").id
    options["vm_name"] = type.include?("master") ? params["master_base_name"] : params["node_base_name"]
    options["vm_memory"] = params[type + "_vm_memory"] if params[type + "_vm_memory"]
    options["cpu"] = params[type + "_cpu"] if params[type + "_cpu"]
    options["instance_type"] = params[type + "_instance_type"] if params[type + "_instance_type"]
    options
  end

  def generate_ssh_keys
    require 'sshkey'
    keys = SSHKey.generate
    [keys.ssh_public_key, keys.private_key]
  end

  def create_deployment_authentication(authentication)
    auth = AUTH_CONSTS[authentication["type"]].new
    auth.authtype = AUTHENTICATIONS_NAMES[authentication["type"]]
    auth.assign_values authentication
    authentications << auth
    save!
  end

  def create_deployment_nodes(nodes)
    work_by_vm_id = method_type.include? "existing_managed"
    nodes.each do |node|
      container_deployment_node = ContainerDeploymentNode.new
      container_deployment_node.address = node["name"] unless work_by_vm_id
      container_deployment_node.vm = Vm.find(node["id"]) if work_by_vm_id
      container_deployment_nodes << container_deployment_node
      node["roles"].each do |key, value|
        if value
          container_deployment_node.tag_add key
        end
      end
      container_deployment_node.save!
    end
  end

  # will be removed once moving to yaml format, no need to review method
  def add_role(role_name)
    template = <<eos
[#{role_name}]
#{send("#{role_name}_addresses".to_sym).join("\n")}
eos
    template
  end

  def create_deployment(params, user)
    self.version = "v3"
    self.kind = params["provider_type"].include?("openshiftOrigin") ? "origin" : "openshift-enterprise"
    self.method_type = params["method_type"]
    create_needed_tags
    if method_type.include? "existing_managed"
      self.deployed_on_ems = ExtManagementSystem.find params["underline_provider_id"]
    elsif method_type.include? "provision"
      ContainerDeployment.add_basic_root_template
      self.deployed_on_ems = ExtManagementSystem.find params["underline_provider_id"]
      public_key, private_key = generate_ssh_keys
      params["ssh_authentication"]["auth_key"] = private_key.chomp
      params["ssh_authentication"]["public_key"] = public_key
      params["ssh_authentication"]["userid"] = "root"
    end
    add_deployment_master_role params["nodes"]
    create_deployment_nodes(params["nodes"])
    create_deployment_authentication(params["identity_authentication"])
    create_deployment_authentication(params["ssh_authentication"].merge("type" => "AuthPrivateKey"))
    create_deployment_authentication(params["rhsm_authentication"].merge("type" => "AuthenticationRhsm"))
    save!
    create_automation_request(generate_automation_params(params), user)
    self
  end

  def add_deployment_master_role(nodes)
    nodes.each do |node|
      if node["roles"]["master"]
        node["roles"]["deployment_master"] = true
        break
      end
    end
  end

  def create_needed_tags(params = {})
    %w(node master deployment_master dns etcd infrastructure load_balancer storage).each do |tag_name|
      find_or_create_by(tag_name)
    end
  end

  def find_or_create_by(tag_name)
    ent = Tag.find_by_name(tag_name)
    unless ent
      ent = Tag.new(:name => tag_name)
      ent.save
    end
  end

  def create_automation_request(parameters, user)
    uri_parts = {
      "namespace" => "ManageIQ/Deployment/ContainerProvider/System/StateMachine",
      "class"     => "Deployment",
      "instance"  => "Deployment"
    }
    requester = {"user_name" => "admin", "auto_approve" => true}
    parameters = parameters.inject({}) { |memo, (k, v)| memo[k.to_s] = v; memo }
    AutomationRequest.create_from_ws("1.1", user, uri_parts, parameters, requester)
  end
end
