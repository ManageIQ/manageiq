FactoryGirl.define do
  factory :filesystem do
    sequence(:name)     { |n| "filesystem_#{seq_padded_for_sorting(n)}" }
  end

  factory :filesystem_conf_file_ascii, :parent => :filesystem do
    name "/etc/nova/nova.conf"
    contents <<-EOT
## NB: Unpolished config file
## This config file was taken directly from the upstream repo, and tweaked just enough to work.
## It has not been audited to ensure that everything present is either Heat controlled or a mandatory as-is setting.
## Please submit patches for any setting that should be deleted or Heat-configurable. '"-"'
##  https://git.openstack.org/cgit/openstack/tripleo-image-elements


[DEFAULT]


s3_host=192.0.2.10
ec2_dmz_host=192.0.2.10
ec2_url=http://192.0.2.10:8773/services/Cloud

my_ip=192.0.2.13
    EOT
  end

  factory :filesystem_conf_file_non_ascii, :parent => :filesystem_conf_file_ascii do
    contents "abc\u{4242}"
  end

  factory :filesystem_binary_file, :parent => :filesystem do
    name "periodical/utilities/blue_screen.exe"
  end

  factory :filesystem_txt_file, :parent => :filesystem do
    name "periodical/utilities/blue_screen_description.txt"
  end
end
