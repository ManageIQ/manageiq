class ContainerDeploymentNode < ApplicationRecord
  belongs_to :vm
  belongs_to :container_deployment
  serialize :labels, Hash
  serialize :customizations, Hash
  acts_as_miq_taggable

  def node_address
    if vm
      vm.hardware.ipaddresses.last || vm.hostnames.last
    elsif address
      address
    end
  end

  def roles
    tags.reset
    tags.collect { |tag| tag.name.gsub("/user/", "").gsub("deployment_master", "master") }.uniq
  end

  def to_ansible_config_format
    node_roles = roles
    infra_node = node_roles.delete("infrastructure")
    config = {
      "connect_to" => node_address,
      "roles"      => node_roles
    }
    config["node_labels"] = {"region" => "infra"} if infra_node
    config
  end
end
