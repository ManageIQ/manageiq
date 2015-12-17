require "spec_helper"

describe ContainerDashboardService do
  context "providers" do
    it "filters containers providers with zero entity count and sorts providers by type correctly" do
      FactoryGirl.create(:ems_openshift, :hostname => "test2.com")
      FactoryGirl.create(:ems_openshift_enterprise, :hostname => "test3.com")
      FactoryGirl.create(:ems_atomic, :hostname => "test4.com")
      FactoryGirl.create(:ems_atomic_enterprise, :hostname => "test5.com")

      providers_data = ContainerDashboardService.new(nil, nil).providers

      # Kubernetes should not appear
      expect(providers_data).to eq([{
                                      :iconClass    => "pficon pficon-openshift",
                                      :count        => 2,
                                      :id           => :openshift,
                                      :providerType => :Openshift
                                    },
                                    {
                                      :iconClass    => "pficon pficon-atomic",
                                      :count        => 2,
                                      :id           => :atomic,
                                      :providerType => :Atomic
                                    }])
    end
  end
end
