class EmsClusterOpenstackInfra < EmsCluster

  def direct_vms
    vms
  end

  # Direct Vm relationship methods
  def direct_vm_rels
    # Look for only the Vms at the second depth (default RP + 1)
    direct_vms
  end

  def direct_vm_ids
    direct_vms.collect(&:id)
  end
end
