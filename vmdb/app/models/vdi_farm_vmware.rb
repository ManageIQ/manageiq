class VdiFarmVmware < VdiFarm
  def inventory_class
    return @inventory_class if @inventory_class

    $:.push("#{File.dirname(__FILE__)}/../../../lib/VdiVmware")
    require 'VdiVmwareInventory'
    @inventory_class = VdiVmwareInventory
  end

  def service_class
    return @service_class if @service_class

    $:.push("#{File.dirname(__FILE__)}/../../../lib/VdiVmware")
    require 'VdiVmwareService'
    @service_class = VdiVmwareService
  end

  def has_broker?
    true
  end

  def allowed_emses
    EmsVmware.all
  end

  def allowed_assignment_behaviors
    {
      "Pooled"           => "Floating",
      "AssignOnFirstUse" => "Dedicated (Automatic Assignment)"
    }
  end


end
