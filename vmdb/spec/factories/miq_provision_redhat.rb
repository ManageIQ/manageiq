FactoryGirl.define do
  factory :miq_provision_redhat do
  end

  factory :miq_provision_redhat_via_iso, :parent => :miq_provision_redhat, :class => "MiqProvisionRedhatViaIso" do
  end

  factory :miq_provision_redhat_via_pxe, :parent => :miq_provision_redhat, :class => "MiqProvisionRedhatViaPxe" do
  end
end
