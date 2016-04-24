class ContainerDeploymentNode < ApplicationRecord
  belongs_to :vm
  belongs_to :container_deployment
  serialize :labels, Hash
  serialize :customizations, Hash
  acts_as_miq_taggable

  def node_address
    if vm
      vm.hardware.ipaddresses.last
    elsif address
      address
    end
  end

  def labels_hash
    labels = {}
    labels.each do |key,val|
      labels[key] = val
    end
    labels
  end

  def roles
    roles = []
    self.tags.each do |tag|
      roles = tag.name.split("/").last
    end
    roles
  end

  def ansible_config_format
    hash = {}
    hash[:connect_to] = address
    hash[:hostname] = vm.hostnames.last unless  vm.hostnames.empty?
    hash[:node_labels] = labels_hash if roles.include?("node") && !labels_hash.empty?
    hash[:roles] = roles
    hash
  end
end
