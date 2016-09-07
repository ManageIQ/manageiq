describe OpsController::RbacTree do
  let(:role) do
    # Pick a small subset of the product features tree to allow the spec to
    #   exercise building more than a single node
    FactoryGirl.create(:miq_user_role, :features =>
      %w(all_vm_rules instance instance_view instance_show_list instance_control instance_scan)
    )
  end

  it ".build" do
    features_tree = described_class.build(role, role.feature_identifiers.sort, false).to_json
    expect(features_tree).to include("Access Rules for all Virtual Machines")
  end
end
