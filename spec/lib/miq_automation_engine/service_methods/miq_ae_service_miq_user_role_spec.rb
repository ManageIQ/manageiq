module MiqAeServiceMiqUserRoleSpec
  describe MiqAeMethodService::MiqAeServiceMiqUserRole do
    before(:each) do
      @role = FactoryGirl.create(:miq_user_role, :name => "Role1")
    end

    it "check name" do 
      expect(@role.name).to eq("Role1")
    end

  end
end
