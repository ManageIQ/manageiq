require "spec_helper"
require Rails.root.join('db/migrate/20110822140627_add_settings_to_miq_group.rb')

describe AddSettingsToMiqGroup do

  migration_context :up do
    let(:miq_group_stub)     { migration_stub(:MiqGroup) }
    let(:miq_user_role_stub) { migration_stub(:MiqUserRole) }

    it 'Copying report_menus setting from MiqUserRole to MiqGroup' do
      miq_user_role = miq_user_role_stub.create!(:settings => {:report_menus => {:data => :fake}})
      miq_group_stub.create!(:miq_user_role => miq_user_role)

      migrate

      MiqGroup.first.settings[:report_menus].should == {:data => :fake}
    end

    it 'handle miq_groups with a nil miq_user_role' do
      miq_group_stub.create!

      migrate
    end
  end
end
