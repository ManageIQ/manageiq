class ContainerDeployment < ApplicationRecord
  belongs_to :deployed_ems, :class_name => 'ManageIQ::Providers::ContainerManager'
  belongs_to :deployed_on_ems, :class_name => 'ExtManagementSystem', :inverse_of => :container_deployments
  belongs_to :automation_task
  has_many :container_deployment_nodes, :dependent => :destroy
  has_many :container_volumes, :as => :parent
  has_many :custom_attributes, :as => :resource, :dependent => :destroy
  has_many :authentications, :as => :resource, :dependent => :destroy
  serialize :customizations, Hash
  AUTHENTICATIONS_TYPES = {:AllowAllPasswordIdentityProvider => AuthenticationAllowAll, :HTPasswdPasswordIdentityProvider => AuthenticationHtpasswd, :LDAPPasswordIdentityProvider => AuthenticationLdap, :RequestHeaderIdentityProvider => AuthenticationRequestHeader, :OpenIDIdentityProvider => AuthenticationOpenId, :GoogleIdentityProvider => AuthenticationGoogle, :GitHubIdentityProvider => AuthenticationGithub, :ssh => AuthPrivateKey, :rhsm => AuthenticationRhsm}.freeze
  AUTHENTICATIONS_NAMES = {:AllowAllPasswordIdentityProvider => "all", :HTPasswdPasswordIdentityProvider => "htPassword", :LDAPPasswordIdentityProvider => "ldap", :RequestHeaderIdentityProvider => "requestHeader", :OpenIDIdentityProvider => "openId", :GoogleIdentityProvider => "google", :GitHubIdentityProvider => "github", :ssh => "ssh", :rhsm => "rhsm"}.freeze

  def ssh_auth
    authentications.where(:type => "AuthPrivateKey").first
  end

  def rhsm_auth
    authentications.where(:type => "AuthenticationRhsm").first
  end

  def identity_provider_auth
    authentications.where.not(:type => "AuthPrivateKey").where.not(:type => "AuthenticationRhsm")
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

  def nfs_addresses
    addresses_array container_deployment_nodes.find_tagged_with(:any => "/user/nfs", :ns => "*")
  end

  def masters_addresses
    addresses_array masters
  end

  def deployment_master_address
    extract_public_ip_or_hostname deployment_master
  end

  def nodes_addresses
    addresses_array(nodes, true)
  end

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
ansible_ssh_user=#{ssh_auth.userid}
deployment_type=openshift-enterprise
rhsub_user=#{rhsm_auth.rhsm_user}
rhsub_pass=#{rhsm_auth.password_encrypted}
rhsub_pool=#{rhsm_auth.rhsm_sku}

[masters]
#{masters_addresses.join("\n") unless masters.empty?}

[nodes]
#{nodes_addresses.join("\n") unless nodes.empty?}
eos
    template
  end

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
#{add_role("nfs") unless nfs_addresses.empty?}

[masters]
#{(deployment_master_address.to_s + " ansible_connection=local openshift_scheduleable=True") unless deployment_master_address.nil?}
    #{masters_addresses.join("\n") unless masters.empty?}
[nodes]
#{nodes_addresses.join("\n") unless nodes.empty?}
eos
    template
  end

  def generate_ansible_yaml
    hash = {}
    hash[:version] = version
    hash[:deployment] = {}
    hash[:deployment][:ansible_config] = "/usr/share/atomic-openshift-utils/ansible.cfg"
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
    hash.to_yaml
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
    return deployment_node.address if deployment_node.address
    return "" if method_type.include? "managed_provision"
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
      :deployment_type          => kind.to_s,
      :deployment_method        => method_type,
      :deployment_id            => id,
      :provider_name            => params["providerName"],
      :ssh_private_key          => [ssh_auth.auth_key_encrypted],
      :ssh_username             => ssh_auth.userid,
      :inventory                => generate_ansible_inventory,
      :rhel_subscribe_inventory => generate_ansible_inventory_for_subscription,
      :containerized            => containerized,
      :rhsub_user               => rhsm_auth.rhsm_user,
      :rhsub_pass               => rhsm_auth.password_encrypted,
      :rhsub_pool               => rhsm_auth.rhsm_sku
    }
    if method_type.include? "managed_provision"
      parameters_provision = { # provision
        :masters_provision => {
          :number_of_vms  => params["masters_addresses"].count + 1,
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
            "ssh_public_key" => ssh_auth.public_key
          }
        },
        :nodes_provision   => {
          :number_of_vms  => params["nodes_addresses"].count,
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
            "ssh_public_key" => ssh_auth.public_key
          }
        },
        :ssh_public_key    => ssh_auth.public_key
      }
      parameters.merge parameters_provision
    else
      parameters_existing = { # non-managed + managed-existing
        :deployment_master => deployment_master_address,
        :masters           => masters_addresses,
        :nodes             => nodes_addresses
      }
      parameters.merge parameters_existing
    end
  end

  def vm_fields(type, params)
    options = {}
    options["customization_template_id"] = CustomizationTemplate.find_by_name("Basic root pass template").id
    options["vm_name"] = params[type + "_base_name"]
    options["vm_memory"] = params[type + "_vm_memory"] if params[type + "_vm_memory"]
    options["cpu"] = params[type + "_cpu"] if params[type + "_cpu"]
    options["instance_type"] = params[type + "_instance_type"] if params[type + "_instance_type"]
    options
  end

  def generate_ssh_keys
    require 'sshkey'
    keys = SSHKey.generate
    [keys.public_key, keys.private_key]
  end

  def create_deployment_authentication(options)
    auth = AUTHENTICATIONS_TYPES[AUTHENTICATIONS_NAMES.key(options["mode"]).to_sym].new
    auth.authtype = options["mode"]
    unless options[options["mode"]].nil? || options[options["mode"]].empty?
      auth.assign_values options[options["mode"]]
    end
    authentications << auth
    save!
  end

  def create_deployment_nodes(vm_groups, labels, tags, vm_id = nil, address = nil)
    vm_groups.each_with_index do |vms, index|
      vms.each do |vm_attr|
        container_deployment_node = ContainerDeploymentNode.where((address ? :address : :vm_id) => vm_attr["vmName"])
                                                           .where(:container_deployment_id => id)
        if container_deployment_node.empty?
          container_deployment_node = ContainerDeploymentNode.new
          container_deployment_node.address = vm_attr["vmName"] if address
          container_deployment_node.vm = Vm.find(vm_attr["vmName"]) if vm_id
          container_deployment_nodes << container_deployment_node
        else
          container_deployment_node = container_deployment_node.first
        end
        container_deployment_node.labels = JSON.parse(labels[vm_attr["vmName"]].to_json).to_h if labels && labels[vm_attr["vmName"]]
        container_deployment_node.tag_add tags[index]
        container_deployment_node.save!
      end
    end
  end

  def add_role(role_name)
    template = <<eos
[#{role_name}]
#{send("#{role_name}_addresses".to_sym).join("\n")}
eos
    template
  end

  def create_deployment(params, user)
    byebug
    self.version = "v3"
    self.kind = params["providerType"].include?("openshiftOrigin") ? "origin" : "openshift-enterprise"
    self.method_type = params["provisionOn"]
    tags = create_needed_tags(params)
    labels = params[:labels]
    if method_type.include? "existingVms"
      managed_existing(params, tags, labels)
    elsif method_type.include? "newVms"
      managed_provision(params, tags, labels)
    else
      unmanaged(params, tags, labels)
    end
    create_deployment_authentication(params["authentication"])
    create_deployment_authentication("ssh" => {"userid" => params["deploymentUsername"], "auth_key" => params["deploymentKey"], "public_key" => params["public_key"]}, "mode" => "ssh")
    create_deployment_authentication("rhsm" => {"userid" => params["rhnUsername"], "password" => params["rhnPassword"], "rhsm_sku" => params["rhnSKU"]}, "mode" => "rhsm")
    save!
    create_automation_request(generate_automation_params(params), user)
  end

  def managed_existing(params, tags, labels)
    self.deployed_on_ems = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    create_deployment_nodes([params["nodes_addresses"], params["masters_addresses"], [params["deployment_master_address"]]] + add_additional_roles(params), labels, tags, true)
  end

  def managed_provision(params, tags, labels)
    ContainerDeployment.add_basic_root_template
    self.deployed_on_ems = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    public_key, private_key = generate_ssh_keys
    params["ssh_authentication"]["auth_key"] = private_key
    params["ssh_authentication"]["public_key"] = public_key
    params["ssh_authentication"]["userid"] = "root"
    create_deployment_nodes([params["nodes_addresses"], params["masters_addresses"], [params["deployment_master_address"]]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def unmanaged(params, tags, labels)
    deployment_master = params["masters"].shift
    create_deployment_nodes([params["nodes"], params["masters"], [deployment_master]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def create_needed_tags(params)
    node_tag = create_or_get_tag("node").name
    master_tag = create_or_get_tag("master").name
    deployment_master_tag = create_or_get_tag("deployment_master").name
    tags = [node_tag, master_tag, deployment_master_tag]
    nfs_tag = create_or_get_tag("nfs").name if params["nfs_id_or_ip"]
    tags += [nfs_tag] if nfs_tag
    tags
  end

  def add_additional_roles(params)
    additional_roles_vms = []
    additional_roles_vms = [params["nfs_id_or_ip"]] if params["nfs_id_or_ip"]
    additional_roles_vms
  end

  def create_or_get_tag(tag)
    ent = Tag.find_by_name(tag)
    unless ent
      ent = Tag.new(:name => tag)
      ent.save
    end
    ent
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
