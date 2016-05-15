class ContainerDeploymentNode < ApplicationRecord
  belongs_to :vm
  belongs_to :container_deployment
  serialize :labels, Hash
  serialize :customizations, Hash
  acts_as_miq_taggable

  def node_address
    if vm
      vm.hostnames.last || vm.hardware.ipaddresses.last
    elsif address
      address
    end
  end

  def labels_hash
    labels = {}
    labels.each do |key, val|
      labels[key] = val
    end
    labels
  end

  def roles
    roles = []
    self.tags.reset if tags.empty?
    tags.each do |tag|
      tag_entry = tag.name.split("/").last
      roles << tag_entry
    end
    roles
  end

  def node_main_role
    return "node" if roles.include? "node"
    "master"
  end

  def ansible_config_format
    hash = {}
    hash[:connect_to] = node_address
    hash[:hostname] = vm.hostnames.last if vm && !vm.hostnames.empty?
    hash[:node_labels] = labels_hash if roles.include?("node") && !labels_hash.empty?
    hash[:roles] = node_main_role
    hash
  end
end
