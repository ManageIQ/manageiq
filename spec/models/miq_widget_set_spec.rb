require "spec_helper"

describe MiqWidgetSet do
  let(:group) { FactoryGirl.create(:miq_group, :description => 'dev group') }
  let(:user)  { FactoryGirl.create(:user, :name => 'cloud', :userid => 'cloud', :miq_groups => [group]) }
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

    it "no longer belonging to a group" do
      user.destroy_widget_sets_for_group(group.id)
      expect(MiqWidgetSet.count).to eq(1)
    end

    it "the belong to group is being deleted" do
      expect { group.destroy }.to raise_error
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
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => user.userid, :group_id => group2.id )
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
end
