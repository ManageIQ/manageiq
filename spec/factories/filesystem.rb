FactoryBot.define do
  factory :filesystem do
    sequence(:name)     { |n| "filesystem_#{seq_padded_for_sorting(n)}" }
    size { 200 }
  end

  factory :filesystem_openstack_conf, :parent => :filesystem do
    name { "etc/nova/nova.conf" }
  end

  factory :filesystem_binary_file, :parent => :filesystem do
    name { "periodical/utilities/blue_screen.exe" }
  end

  factory :filesystem_txt_file, :parent => :filesystem do
    name { "periodical/utilities/blue_screen_description.txt" }
  end
end
