describe ConfiguredSystem do
  it "#counterparts" do
    vm  = FactoryBot.create(:vm)
    cs1 = FactoryBot.create(:configured_system, :counterpart => vm)
    cs2 = FactoryBot.create(:configured_system, :counterpart => vm)
    cs3 = FactoryBot.create(:configured_system, :counterpart => vm)

    expect(cs1.counterparts).to match_array([vm, cs2, cs3])
  end
end
