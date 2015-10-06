require "spec_helper"
require_migration

describe ChangeUtcTimeProfileTypeToGlobal do
  migration_context :up do
    let(:time_profile_stub) { migration_stub(:TimeProfile) }

    it 'default UTC Time Profile gets updated' do
      tp = time_profile_stub.create!(:description => 'UTC', :profile_type => nil)

      migrate

      tp.reload
      tp.profile_type.should == 'global'
    end
  end
end
