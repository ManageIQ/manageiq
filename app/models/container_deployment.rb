class ContainerDeployment < ApplicationRecord
  include_concern "Automate"
  belongs_to :deployed_ems, :class_name => 'ManageIQ::Providers::ContainerManager'
  belongs_to :deployed_on_ems, :class_name => 'ExtManagementSystem', :inverse_of => :container_deployments
  belongs_to :automation_task
  has_many :container_deployment_nodes, :dependent => :destroy
  has_many :container_volumes, :as => :parent
  has_many :custom_attributes, :as => :resource, :dependent => :destroy
  has_many :authentications, :as => :resource, :dependent => :destroy
  DEPLOYMENT_TYPES = %w(origin openshift-enterprise).freeze
  serialize :customizations, Hash
  AUTHENTICATIONS_NAMES = {"AuthenticationAllowAll"      => "AllowAllPasswordIdentityProvider",
                           "AuthenticationHtpasswd"      => "HTPasswdPasswordIdentityProvider",
                           "AuthenticationLdap"          => "LDAPPasswordIdentityProvider",
                           "AuthenticationRequestHeader" => "RequestHeaderIdentityProvider",
                           "AuthenticationOpenId"        => "OpenIDIdentityProvider",
                           "AuthenticationGoogle"        => "GoogleIdentityProvider",
                           "AuthenticationGithub"        => "GitHubIdentityProvider",
                           "AuthPrivateKey"              => "ssh",
                           "AuthenticationRhsm"          => "rhsm"}.freeze
  ANSIBLE_CONFIG_LOCATION = "/usr/share/atomic-openshift-utils/ansible.cfg".freeze
  ANSIBLE_CONFIG_LOG = "/tmp/ansible.log".freeze
  ANSIBLE_CONFIG_INVENTORY_PATH = "/tmp/inventroy.yaml".freeze

  def ssh_auth
    authentications.find_by(:type => "AuthPrivateKey")
  end

  def rhsm_auth
    authentications.find_by(:type => "AuthenticationRhsm")
  end

  def identity_provider_auth
    authentications.where.not(:type => %w(AuthPrivateKey AuthenticationRhsm))
  end

  def roles_addresses(role)
    if role.include?("deployment_master")
      extract_public_ip_or_hostname(container_nodes_by_role(role).first)
    else
      addresses_array(container_nodes_by_role(role))
    end
  end

  def container_nodes_by_role(role)
    container_deployment_nodes.find_tagged_with(:any => "/user/#{role}", :ns => "*")
  end

  def addresses_array(container_deployment_nodes)
    container_deployment_nodes.collect(&:node_address)
  end

  def add_deployment_provider(options)
    provider = ExtManagementSystem.new(
      :type      => options[:provider_type],
      :name      => options[:provider_name],
      :port      => options[:provider_port],
      :hostname  => options[:provider_hostname],
      :ipaddress => options[:provider_ipaddress],
      :zone      => Zone.default_zone
    )
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

  def generate_ansible_inventory_for_subscription
    <<EOS
[OSEv3:children]
nodes

[OSEv3:vars]
ansible_ssh_user=#{ssh_auth.userid}
deployment_type=openshift-enterprise
rhsub_user=#{rhsm_auth.userid}
rhsub_pass=#{rhsm_auth.password}
rhsub_pool=#{rhsm_auth.rhsm_sku}
ansible_become=true

[nodes]
#{needed_subscription_addresses.join("\n")}
EOS
  end

  def generate_ansible_yaml
    config = {
      "ansible_config"         => ANSIBLE_CONFIG_LOCATION,
      "ansible_log_path"       => ANSIBLE_CONFIG_LOG,
      "ansible_inventory_path" => ANSIBLE_CONFIG_INVENTORY_PATH,
      "deployment"             => {
        "ansible_ssh_user" => ssh_auth.userid,
        "hosts"            => container_deployment_nodes.collect(&:to_ansible_config_format),
        "roles"            => generate_roles
      },
      "version"                => version,
      "variant_version"        => kind.include?("origin") ? '1.2' : '3.2',
      "variant"                => kind
    }
    if container_deployment_nodes.collect(&:roles).flatten.uniq.include?("master_lb")
      config["deployment"].merge!(
        "openshift_master_cluster_method"          => "native",
        "openshift_master_cluster_hostname"        => roles_addresses("master_lb").first,
        "openshift_master_cluster_public_hostname" => roles_addresses("master_lb").first
      )
    end
    config.to_yaml.gsub("---\n", '')
  end

  def create_deployment(params, user)
    self.version = "v2"
    self.kind = params["provider_type"].include?("openshiftOrigin") ? "origin" : "openshift-enterprise"
    self.method_type = params["method_type"]
    create_needed_tags
    if method_type.include?("existing_managed")
      self.deployed_on_ems = ExtManagementSystem.find(params["underline_provider_id"])
    elsif method_type.include?("provision")
      self.deployed_on_ems = ExtManagementSystem.find(params["underline_provider_id"])
      keys = generate_ssh_keys
      public_key = keys[:public_key]
      private_key = keys[:private_key]
      params["ssh_authentication"]["auth_key"] = private_key.chomp
      params["ssh_authentication"]["public_key"] = public_key
      params["ssh_authentication"]["userid"] = "root"
    end
    add_deployment_master_role(params["nodes"])
    create_deployment_nodes(params["nodes"])
    create_deployment_authentication(params["identity_authentication"])
    create_deployment_authentication(params["ssh_authentication"].merge("type" => "AuthPrivateKey"))
    create_deployment_authentication(params["rhsm_authentication"].merge("type" => "AuthenticationRhsm"))
    save!
    create_automation_request(generate_automation_params(params), user)
    self
  end

  def create_deployment_authentication(authentication)
    auth = authentication["type"].safe_constantize.new
    auth.authtype = AUTHENTICATIONS_NAMES[authentication["type"]]
    auth.assign_values(authentication)
    authentications << auth
    save!
  end

  def extract_public_ip_or_hostname(deployment_node)
    return deployment_node.address if deployment_node.vm_id.nil?
    vm = deployment_node.vm
    ips = vm.hardware.ipaddresses
    ips.detect { |ip| ip if public_ip?(ip) } || ips.last
  end

  def create_deployment_nodes(nodes)
    work_by_vm_id = method_type.include?("existing_managed")
    nodes.each do |node|
      container_deployment_node = ContainerDeploymentNode.new
      container_deployment_node.address = node["name"] unless work_by_vm_id
      container_deployment_node.vm = Vm.find(node["id"]) if work_by_vm_id
      container_deployment_nodes << container_deployment_node
      node["roles"].each do |key, value|
        if value
          container_deployment_node.tag_add(key)
        end
      end
      container_deployment_node.save!
    end
  end

  def create_needed_tags(_params = {})
    %w(node master deployment_master dns etcd infrastructure master_lb storage).each do |tag_name|
      find_or_create_by(tag_name)
    end
  end

  def identity_ansible_config_format
    authentication = identity_provider_auth.first
    options = {}
    case authentication.type
    when "AuthenticationGithub"
      options = {
        "clientID"            => authentication.userid,
        "clientSecret"        => authentication.password,
        "challenge"           => "false",
        "githubOrganizations" => authentication.github_organizations
      }
    when "AuthenticationGoogle"
      options = {
        "clientID"     => authentication.userid,
        "clientSecret" => authentication.password,
        "hostedDomain" => authentication.google_hosted_domain,
        "challenge"    => "false"
      }
    when "AuthenticationHtpasswd"
      options = {
        "filename" => "/etc/origin/master/htpasswd"
      }
    when "AuthenticationLdap"
      options = {
        "attributes"   => {"id"                => authentication.ldap_id,
                           "email"             => authentication.ldap_email,
                           "name"              => authentication.ldap_name,
                           "preferredUsername" => authentication.ldap_preferred_user_name},
        "bindDN"       => authentication.ldap_bind_dn,
        "bindPassword" => authentication.password,
        "ca"           => authentication.certificate_authority,
        "insecure"     => authentication.ldap_insecure.to_s,
        "url"          => authentication.ldap_url
      }
    when "AuthenticationOpenId"
      options = {
        "clientID"                       => authentication.userid,
        "clientSecret"                   => authentication.password,
        "claims"                         => {"id" => authentication.open_id_sub_claim},
        "urls"                           => {"authorize" => authentication.open_id_authorization_endpoint, "toekn" => authentication.open_id_token_endpoint},
        "challenge"                      => "false",
        "openIdExtraAuthorizeParameters" => authentication.open_id_extra_authorize_parameters,
        "openIdExtraScopes"              => authentication.open_id_extra_scopes
      }
    when "AuthenticationRequestHeader"
      options = {
        "challengeURL"                          => authentication.request_header_challenge_url,
        "loginURL"                              => authentication.request_header_login_url,
        "clientCA"                              => authentication.certificate_authority,
        "headers"                               => authentication.request_header_headers,
        "requestHeaderPreferredUsernameHeaders" => authentication.request_header_preferred_username_headers,
        "requestHeaderNameHeaders"              => authentication.request_header_name_headers,
        "requestHeaderEmailHeaders"             => authentication.request_header_email_headers
      }
    end
    {'name' => "example_name", 'login' => "true", 'challenge' => "true", 'kind' => authentication.authtype}.merge!(options)
  end

  private

  def generate_ssh_keys
    require 'sshkey'
    keys = SSHKey.generate
    {:public_key => keys.ssh_public_key, :private_key => keys.private_key}
  end

  def num_of_nodes
    nodes = container_deployment_nodes.find_tagged_with(:any => "/user/node", :ns => "*")
    (nodes.select { |node| !node.is_tagged_with?("/master") }).count
  end

  def generate_roles
    result = {}
    roles = container_deployment_nodes.collect(&:roles).flatten.uniq
    result["master"] = {"osm_use_cockpit"                     => "false",
                        "openshift_master_identity_providers" => [identity_ansible_config_format]} if roles.include?("master")
    unless identity_provider_auth.first.htpassd_users.empty?
      result["master"]["openshift_master_htpasswd_users"] = htpasswd_hash
    end
    result["node"] = {} if roles.include?("node")
    result["storage"] = {} if roles.include?("storage")
    result["etcd"] = {} if roles.include?("etcd")
    result["master_lb"] = {} if roles.include?("master_lb")
    result["dns"] = {} if roles.include?("dns")
    result
  end

  def needed_subscription_addresses
    addresses = container_deployment_nodes.collect(&:node_address)
    addresses.delete(roles_addresses("deployment_master"))
    addresses
  end

  def public_ip?(ip)
    require "socket"
    return ip unless Addrinfo.tcp(ip, 80).ipv4_private?
  end

  def generate_automation_params(params)
    parameters = { # for all
      :deployment_type   => kind.to_s,
      :deployment_method => method_type,
      :deployment_id     => id,
      :provider_name     => params["provider_name"],
      :containerized     => containerized,
      :rhsub_sku         => rhsm_auth.rhsm_sku
    }
    if method_type.include?("provision")
      node_template = VmOrTemplate.find(params["nodes_creation_template_id"])
      master_template = VmOrTemplate.find(params["masters_creation_template_id"])
      parameters_provision = {
        :ssh_public_key        => ssh_auth.public_key,
        :provision_provider_id => deployed_on_ems.id,
        :masters_provision     => {
          :number_of_vms  => container_nodes_by_role("master").count,
          :templateFields => {
            "guid" => master_template.guid, "name" => master_template.name
          },
          :vmFields       => vm_fields("masters", params),
          :requester      => {
            'owner_email'      => 'something@example.com',
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
            "guid" => node_template.guid, "name" => node_template.name
          },
          :vmFields       => vm_fields("nodes", params),
          :requester      => {
            'owner_email'      => 'something@example.com',
            'owner_first_name' => 'temp',
            'owner_last_name'  => 'temp'
          },
          :tags           => nil,
          :ws_values      => {
            "ssh_public_key" => ssh_auth.public_key
          }
        },
      }
      parameters.merge(parameters_provision)
    else
      parameters_existing = { # non-managed + managed-existing
        :deployment_master => roles_addresses("deployment_master")
      }
      parameters.merge(parameters_existing)
    end
  end

  def vm_fields(type, params)
    options = {}
    options["customization_template_id"] = CustomizationTemplate.find_by(:name => "SSH key addition template").id
    options["vm_name"] = params["#{type.singularize}_base_name"]
    options["vm_memory"] = params[type + "_vm_memory"] if params[type + "_vm_memory"]
    options["cpu"] = params[type + "_cpu"] if params[type + "_cpu"]
    if deployed_on_ems.kind_of?(ManageIQ::Providers::Amazon::CloudManager)
      options["instance_type"] = 1 || params[type + "_instance_type"]
      options["placement_auto"] = true
    end
    options
  end

  def add_deployment_master_role(nodes)
    nodes.each do |node|
      if node["roles"]["master"]
        node["roles"]["deployment_master"] = true
        break
      end
    end
  end

  def htpasswd_hash
    require 'htauth/md5'
    salt = (0...8).map { (65 + rand(26)).chr }.join
    md5 = HTAuth::Md5.new('salt' => salt)
    htpass_hash = {}
    users = []
    identity_provider_auth.first.htpassd_users.each do |user|
      users << JSON.parse(user.as_json.gsub(/\=\>/, ':'))
    end
    users.each do |user|
      user["password"] = md5.encode(user["password"])
      htpass_hash[(user['username']).to_s] = user["password"]
    end
    htpass_hash
  end

  def find_or_create_by(tag_name)
    ent = Tag.find_by(:name => tag_name)
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
    parameters = parameters.each_with_object({}) { |(k, v), memo| memo[k.to_s] = v }
    AutomationRequest.create_from_ws("1.1", user, uri_parts, parameters, requester)
  end
end
