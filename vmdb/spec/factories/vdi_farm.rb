FactoryGirl.define do
  factory :vdi_farm do
  end

  factory :vdi_farm_vmware, :parent => :vdi_farm, :class => :VdiFarmVmware do
    sequence(:name)  { |n| "VdiFarm VMware #{n}" }
    vendor    "vmware"
  end

  factory :vdi_farm_citrix, :parent => :vdi_farm, :class => :VdiFarmCitrix do
    sequence(:name)  { |n| "VdiFarm Citrix #{n}" }
    vendor    "citrix"
  end

end
