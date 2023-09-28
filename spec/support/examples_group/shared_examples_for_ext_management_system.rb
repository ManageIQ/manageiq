shared_examples_for "ExtManagementSystem#pause!" do
  before { Zone.seed }

  it "disables the manager and moves it to the maintenance zone" do
    ems.pause!

    ems.reload

    expect(ems.enabled).to eq(false)
    expect(ems.zone).to eq(Zone.maintenance_zone)
    expect(ems.zone_before_pause).to eq(zone)
  end

  it "disables all child managers and moves them to the maintenance zone" do
    ems.pause!

    ems.reload

    ems.child_managers.each do |child_manager|
      expect(child_manager.enabled).to eq(false)
      expect(child_manager.zone).to eq(Zone.maintenance_zone)
      expect(child_manager.zone_before_pause).to eq(zone)
    end
  end
end

shared_examples_for "ExtManagementSystem#resume!" do
  before { Zone.seed }

  it "resumes the manager and moves it to the original zone" do
    ems.pause!
    ems.reload
    ems.resume!
    ems.reload

    expect(ems.enabled).to eq(true)
    expect(ems.zone).to eq(zone)
    expect(ems.zone_before_pause).to be_nil
  end
end
