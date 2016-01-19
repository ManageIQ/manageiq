describe LdapUser do
  context "with a small envs" do
    before(:each) do
      @task = FactoryGirl.create(:miq_task)
    end

    it "Assignment" do
      lm = FactoryGirl.create(:ldap_user, :dn => "manager")
      lu = FactoryGirl.create(:ldap_user, :dn => "employee")

      lm.direct_reports << lu

      expect(lm.direct_reports.size).to eq(1)
      expect(lm.managers.size).to eq(0)

      expect(lu.managers.size).to eq(1)
      expect(lu.direct_reports.size).to eq(0)
    end
  end
end
