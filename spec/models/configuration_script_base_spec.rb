describe ConfigurationScriptBase do
  it "has many authentications and vice versa" do
    configuration_script_bases = [FactoryGirl.create(:configuration_script_base),
                                  FactoryGirl.create(:configuration_script_base)]
    authentication1 = FactoryGirl.create(:authentication)
    authentication1.configuration_script_bases = configuration_script_bases
    authentication2 = FactoryGirl.create(:authentication, :configuration_script_bases => configuration_script_bases)
    expect(AuthenticationConfigurationScriptBase.count).to eq(4)
    expect(authentication1.configuration_script_bases).to match_array(configuration_script_bases)
    expect(authentication2.configuration_script_bases).to match_array(configuration_script_bases)
    expect(configuration_script_bases[0].authentications).to match_array([authentication1, authentication2])
  end
end
