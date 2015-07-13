require "spec_helper"

describe LdapUser do
  context "with a small envs" do
    before(:each) do
      @task = FactoryGirl.create(:miq_task)
    end

    it "Assignment" do
      lm = FactoryGirl.create(:ldap_user, :dn => "manager")
      lu = FactoryGirl.create(:ldap_user, :dn => "employee")

      lm.direct_reports << lu

      lm.direct_reports.should have(1).thing
      lm.managers.should have(0).thing

      lu.managers.should have(1).thing
      lu.direct_reports.should have(0).thing
    end
  end
end
