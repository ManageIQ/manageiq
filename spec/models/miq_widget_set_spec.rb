describe MiqWidgetSet do
  let(:group) { user.current_group }
  let(:user)  { FactoryGirl.create(:user_with_group) }
  before do
    @ws_group = FactoryGirl.create(:miq_widget_set, :name => 'Home', :owner => group)
  end

  it "when a group dashboard is deleted" do
    expect(MiqWidgetSet.count).to eq(1)
    @ws_group.destroy
    expect(MiqWidgetSet.count).to eq(0)
  end

  context "with a group" do
    it "being deleted" do
      expect(MiqWidgetSet.count).to eq(1)
      user.miq_groups = []
      group.destroy
      expect(MiqWidgetSet.count).to eq(0)
    end
  end

  context "with a user" do
    before do
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => user.userid, :group_id => group.id)
    end

    it "initial state" do
      expect(MiqWidgetSet.count).to eq(2)
    end

    it "the belong to group is being deleted" do
      expect { group.destroy }.to raise_error(RuntimeError, /The group has users assigned that do not belong to any other group/)
      expect(MiqWidgetSet.count).to eq(2)
    end

    it "being deleted" do
      user.destroy
      expect(MiqWidgetSet.count).to eq(1)
    end
  end

  describe "#where_unique_on" do
    let(:group2) { FactoryGirl.create(:miq_group, :description => 'dev group2') }
    let(:ws_1)   { FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => user.userid, :group_id => group.id) }

    before do
      user.miq_groups << group2
      ws_1
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => user.userid, :group_id => group2.id)
    end

    it "initial state" do
      expect(MiqWidgetSet.count).to eq(3)
    end

    it "brings back all group records" do
      expect(MiqWidgetSet.where_unique_on('Home')).to eq([@ws_group])
    end

    it "brings back records for a user with a group" do
      expect(MiqWidgetSet.where_unique_on('Home', user)).to eq([ws_1])
    end
  end

  describe "#with_users" do
    it "brings back records with users" do
      ws_1 = FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => user.userid, :group_id => group.id)
      expect(described_class.with_users).to eq([ws_1])
    end
  end

  context ".find_with_same_order" do
    it "returns in index order" do
      g1 = FactoryGirl.create(:miq_widget_set)
      g2 = FactoryGirl.create(:miq_widget_set)
      expect(MiqWidgetSet.find_with_same_order([g1.id.to_s, g2.id.to_s])).to eq([g1, g2])
    end

    it "returns in non index order" do
      g1 = FactoryGirl.create(:miq_widget_set)
      g2 = FactoryGirl.create(:miq_widget_set)
      expect(MiqWidgetSet.find_with_same_order([g2.id.to_s, g1.id.to_s])).to eq([g2, g1])
    end
  end

  context "loading group specific defaul dashboard" do
    describe ".sync_from_file" do
      let(:dashboard_name) { "Dashboard for Group" }
      before do
        @yml_file = Tempfile.new('default_dashboard_for_group.yaml')
        yml_data = YAML.safe_load(<<~DOC, [Symbol])
          ---
          name: #{dashboard_name}
          read_only: t
          set_type: MiqWidgetSet
          description: Test Dashboard for Group
          owner_type: MiqGroup
          owner_description: #{group.description}
          set_data_by_description:
            :col1:
            - chart_vendor_and_guest_os
        DOC
        File.write(@yml_file.path, yml_data.to_yaml)
      end

      after do
        @yml_file.close(true)
      end

      it "loads dashboard for specific group" do
        described_class.sync_from_file(@yml_file.path)
        dashboard = MiqWidgetSet.find_by(:name => dashboard_name)
        expect(dashboard.owner_id).to eq(group.id)
      end
    end
  end
end
