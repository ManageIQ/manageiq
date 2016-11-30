describe 'ops/_rbac_user_details.html.haml' do
  context "edit user" do
    before do
      user = FactoryGirl.build(:user_with_group, :name => "Joe Test", :userid => "tester")
      allow(view).to receive(:current_tenant).and_return(Tenant.seed)
      allow(view).to receive(:session).and_return(:assigned_filters => [])
      edit = {:new    => {:name   => user.name,
                          :email  => user.email,
                          :userid => user.userid},
              :groups => []}
      view.instance_variable_set(:@edit, edit)
    end

    it "displays full name" do
      render
      expect(rendered).to have_field("name", :with => "Joe Test")
    end
  end
end
