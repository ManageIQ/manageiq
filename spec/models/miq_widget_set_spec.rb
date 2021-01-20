RSpec.describe MiqWidgetSet do
  let(:group) { user.current_group }
  let(:user)  { FactoryBot.create(:user_with_group) }

  let(:miq_widget) { FactoryBot.create(:miq_widget) }

  let(:set_data) do
    {:col1             => [miq_widget.id],
     :reset_upon_login => false,
     :locked           => false}
  end

  before do
    @ws_group = FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'Home', :owner => group)
  end

  describe "validate" do
    it "validates that MiqWidgetSet#name cannot contain \"|\" " do
      widget_set = MiqWidgetSet.create(:name => 'TEST|TEST')

      expect(widget_set.errors.messages).to include(:name => ["cannot contain \"|\""])
    end

    let(:other_group) { FactoryBot.create(:miq_group) }

    it "validates that MiqWidgetSet has unique description inside group" do
      widget_set = MiqWidgetSet.create(:description => @ws_group.description, :owner => group)
      expect(widget_set.errors.messages).to include(:description => ["Description (Tab Title) must be unique for this group"])

      widget_set = MiqWidgetSet.create(:description => @ws_group.description, :owner => nil)
      expect(widget_set.errors.messages).not_to include(:description => ["Description (Tab Title) must be unique for this group"])

      widget_set = MiqWidgetSet.create(:description => @ws_group.description, :owner => other_group)
      expect(widget_set.errors.messages).not_to include(:description => ["Description (Tab Title) must be unique for this group"])
    end

    it "validates that there is at least one widget in set_data" do
      widget_set = MiqWidgetSet.create

      expect(widget_set.errors.messages).to include(:set_data => ["One widget must be selected(set_data)"])
    end

    it "validates that widgets in set_data have to exist" do
      unknown_id = MiqWidgetSet.maximum(:id) + 1
      widget_set = MiqWidgetSet.create(:set_data => {:col1 => [unknown_id]})

      expect(widget_set.errors.messages).to include(:set_data => ["Unable to find widget ids: #{unknown_id}"])
    end

    it "validates that group_id has to be present for non-read_only widget sets" do
      widget_set = MiqWidgetSet.create(:read_only => false)
      expect(widget_set.errors.messages).to include(:group_id => ["can't be blank"])

      widget_set = MiqWidgetSet.create(:read_only => true)
      expect(widget_set.errors.messages).not_to include(:set_data => ["can't be blank"])
    end
  end

  it "when a group dashboard is deleted" do
    expect(MiqWidgetSet.count).to eq(1)
    @ws_group.destroy
    expect(MiqWidgetSet.count).to eq(0)
  end

  context "with a group" do
    it "being deleted" do
      expect(MiqWidgetSet.count).to eq(1)
      user.destroy
      group.destroy
      expect(MiqWidgetSet.count).to eq(0)
    end
  end

  context "with a user" do
    before do
      FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'Home', :userid => user.userid, :group_id => group.id)
    end

    it "initial state" do
      expect(MiqWidgetSet.count).to eq(2)
    end

    it "the belong to group is being deleted" do
      expect { expect { group.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed) }.to_not(change { MiqWidgetSet.count })
      expect(group.errors[:base][0]).to eq("The group has users assigned that do not belong to any other group")
    end

    it "being deleted" do
      user.destroy
      expect(MiqWidgetSet.count).to eq(1)
    end
  end

  describe ".destroy_user_versions" do
    before do
      FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'User_Home', :userid => user.userid, :owner => group)
    end

    it "destroys all user's versions of dashboards (dashboards been customized by user)" do
      expect(MiqWidgetSet.count).to eq(2)
      MiqWidgetSet.destroy_user_versions
      expect(MiqWidgetSet.count).to eq(1)
      expect(MiqWidgetSet.first).to eq(@ws_group)
    end
  end

  describe "#where_unique_on" do
    let(:group2) { FactoryBot.create(:miq_group, :description => 'dev group2') }
    let(:ws_1)   { FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'Home', :userid => user.userid, :group_id => group.id) }

    before do
      user.miq_groups << group2
      ws_1
      FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'Home', :userid => user.userid, :group_id => group2.id)
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
      ws = FactoryBot.create(:miq_widget_set, :set_data => set_data, :name => 'Home', :userid => user.userid, :group_id => group.id)
      expect(described_class.with_users).to eq([ws])
    end
  end

  context ".find_with_same_order" do
    it "returns in index order" do
      g1 = FactoryBot.create(:miq_widget_set, :set_data => set_data, :read_only => true)
      g2 = FactoryBot.create(:miq_widget_set, :set_data => set_data, :read_only => true)
      expect(MiqWidgetSet.find_with_same_order([g1.id.to_s, g2.id.to_s])).to eq([g1, g2])
    end

    it "returns in non index order" do
      g1 = FactoryBot.create(:miq_widget_set, :set_data => set_data, :read_only => true)
      g2 = FactoryBot.create(:miq_widget_set, :set_data => set_data, :read_only => true)
      expect(MiqWidgetSet.find_with_same_order([g2.id.to_s, g1.id.to_s])).to eq([g2, g1])
    end
  end

  context "loading group specific defaul dashboard" do
    let!(:miq_widget_set) { FactoryBot.create(:miq_widget, :description => 'chart_vendor_and_guest_os') }

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

  describe ".copy_dashboard" do
    let(:name)        { "New Dashboard Name" }
    let(:tab)         { "Dashboard Tab" }
    let(:other_group) { FactoryBot.create(:miq_group) }

    it "does not raises error if the same dashboard name used for different groups" do
      expect { MiqWidgetSet.copy_dashboard(@ws_group, @ws_group.name, tab, other_group.id) }.not_to raise_error
    end

    it "raises error if passed tab name is empty" do
      expect { MiqWidgetSet.copy_dashboard(@ws_group, name, "") }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: MiqWidgetSet: Description can't be blank")
    end

    it "raises error if group with passed id does not exist" do
      expect { MiqWidgetSet.copy_dashboard(@ws_group, name, tab, "9999") }.to raise_error(ActiveRecord::RecordNotFound, "Couldn't find MiqGroup with 'id'=9999")
    end

    it "copy dashboard and set its owner to the group with passed group_id" do
      another_group = FactoryBot.create(:miq_group, :description => 'some_group')
      MiqWidgetSet.copy_dashboard(@ws_group, name, tab, another_group.id)
      dashboard = MiqWidgetSet.find_by(:owner_id => another_group.id)
      expect(dashboard.name).to eq(name)
    end

    it "copy dashboard and set its owner to the same group if no group_id parameter passed" do
      expect(MiqWidgetSet.where(:owner_id => group.id).count).to eq(1)
      dashboard = MiqWidgetSet.copy_dashboard(@ws_group, name, tab)
      expect(MiqWidgetSet.find_by(:owner_id => group.id, :name => name)).to eq dashboard
    end

    it "keeps the same set of widgets and dashboard's settings" do
      new_dashboard = MiqWidgetSet.copy_dashboard(@ws_group, name, tab)
      expect(new_dashboard.set_data).to eq @ws_group.set_data
    end
  end
end
