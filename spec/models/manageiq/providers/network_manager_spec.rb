describe ManageIQ::Providers::NetworkManager do
  it "has .hosts and .vms even without a parent_manager" do
    # a NetworkManager doesn't necessarily have a parent_manager, but some methods in ExtManagementSystem
    # require .hosts and .vms to return a relation
    # https://bugzilla.redhat.com/show_bug.cgi?id=1393675
    manager = FactoryGirl.build(:ems_network)
    expect(manager.hosts).be_a(ActiveRecord::Relation)
    expect(manager.vms).be_a(ActiveRecord::Relation)
  end
end
