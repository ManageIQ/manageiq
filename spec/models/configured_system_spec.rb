describe ConfiguredSystem do
  it "#counterparts" do
    vm  = FactoryGirl.create(:vm)
    cs1 = FactoryGirl.create(:configured_system, :counterpart => vm)
    cs2 = FactoryGirl.create(:configured_system, :counterpart => vm)
    cs3 = FactoryGirl.create(:configured_system, :counterpart => vm)

    expect(cs1.counterparts).to match_array([vm, cs2, cs3])
  end
end
