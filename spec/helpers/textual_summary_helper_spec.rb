describe TextualSummaryHelper do
  before do
    login_as @user = FactoryGirl.create(:user)
    allow(@user).to receive(:role_allows?).and_return(true)
  end

  context "textual_link" do
    context "with a restfully-routed model" do
      it "uses the restful path to retrieve the summary screen link" do
        ems = FactoryGirl.create(:ems_openstack)
        ems.availability_zones << FactoryGirl.create(:availability_zone_openstack)

        result = helper.textual_link(ems.availability_zones)
        expect(result[:link]).to eq("/ems_cloud/#{ems.id}?display=availability_zones")
      end

      it "uses the restful path for the base show screen" do
        ems = FactoryGirl.create(:ems_openstack)

        result = helper.textual_link(ems)
        expect(result[:link]).to eq("/ems_cloud/#{ems.id}")
      end
    end

    context "with a non-restful model" do
      it "uses the controller-action-id path to retrieve the summary screen link" do
        ems = FactoryGirl.create(:ems_openstack_infra)
        ems.hosts << FactoryGirl.create(:host)

        result = helper.textual_link(ems.hosts)
        expect(result[:link]).to eq("/ems_infra/#{ems.id}?display=hosts")
      end

      it "uses the controller-action-id path for the base show screen" do
        ems = FactoryGirl.create(:ems_openstack_infra)

        result = helper.textual_link(ems)
        expect(result[:link]).to eq("/ems_infra/#{ems.id}")
      end
    end
  end

  context '#textual_tags' do
    before do
      @record = FactoryGirl.create(:orchestration_template)
      session[:customer_name] = 'RspecName'
    end

    it 'returns tags correctly' do
      parent = FactoryGirl.create(:classification, :description => 'Label')
      value_one = FactoryGirl.create(:classification, :description => 'Value 1', :parent_id => parent.id)
      value_two = FactoryGirl.create(:classification, :description => 'Value 2', :parent_id => parent.id)
      tag_one = Tag.find_by(:id => value_one[:tag_id])
      tag_two = Tag.find_by(:id => value_two[:tag_id])
      tag_one[:name] = '/managed/label/value1'
      tag_two[:name] = '/managed/label/value2'
      tag_one.save!
      tag_two.save!
      @record.tags.push(tag_one)
      @record.tags.push(tag_two)
      tag = helper.textual_tags
      expect(tag[:label]).to eq(_("%{name} Tags") % {:name => session[:customer_name]})
      expect(tag).to eq({:label => "RspecName Tags",
                         :value => [:image => "smarttag", :label => "Label", :value => ["Value 1", "Value 2"]]})
    end

    it 'returns Hash if no tags found' do
      tag = helper.textual_tags
      expect(tag[:label]).to eq(_("%{name} Tags") % {:name => session[:customer_name]})
      expect(tag[:image]).to eq("smarttag")
      expect(tag[:value]).to eq(_("No %{label} Tags have been assigned") % {:label => session[:customer_name]})
    end

    it 'returns Hash if only policies found' do
      tag_policy = FactoryGirl.create(:tag, :name => 'miq_policy/assignment/miq_policy_set/number')
      @record.tags.push(tag_policy)
      tag = helper.textual_tags
      expect(tag[:label]).to eq(_("%{name} Tags") % {:name => session[:customer_name]})
      expect(tag[:image]).to eq("smarttag")
      expect(tag[:value]).to eq(_("No %{label} Tags have been assigned") % {:label => session[:customer_name]})
    end
  end
end
