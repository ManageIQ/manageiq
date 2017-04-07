FactoryGirl.define do
  factory :physical_server do
    id 1
    ems_id 1
    name "IMM-e41f13ed4f6f"
    type "ManageIQ::Providers::Lenovo::PhysicalInfraManager::PhysicalServer"
    uid_ems ""
    ems_ref "A59D5B36821111E1A9F5E41F13ED4F6A"
    created_at "2017-04-05 16:53:31.323215"
    updated_at "2017-04-05 16:53:31.323215"
    health_state "Valid"
    power_state "on"
    hostname "IMM-e41f13ed4f6f"
    product_name "System x3550 M4"
    manufacturer "IBM"
    machine_type "7914"
    model "AC1"
    serial_number "06ARFA2"
    field_replaceable_unit ""
    raw_power_state ""
    vendor "lenovo"
    location_led_state "On"
  end
end
