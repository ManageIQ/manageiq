class VdiFarmCitrix < VdiFarm
  def inventory_class
    return @inventory_class if @inventory_class

    $:.push("#{File.dirname(__FILE__)}/../../../lib/VdiCitrix")
    require 'VdiCitrixInventory'
    @inventory_class = VdiCitrixInventory
  end

  def service_class
    return @service_class if @service_class

    $:.push("#{File.dirname(__FILE__)}/../../../lib/VdiCitrix")
    require 'VdiCitrixService'
    @service_class = VdiCitrixService
  end

  def has_broker?
    true
  end

  def allowed_emses
    return nil if self.version_major_minor.to_i >= 5
    EmsVmware.all
  end

  def allowed_assignment_behaviors
    {
      "Pooled"           => "Pooled",
      "PreAssigned"      => "Pre-assigned",
      "AssignOnFirstUse" => "Assign on first use"
    }
  end

end
