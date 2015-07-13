require "spec_helper"

describe Account do

  before(:each) do
    @user = FactoryGirl.create(:account_user)
    @group = FactoryGirl.create(:account_group)
  end

  it '#accttype_opposite' do
    @user.class.accttype_opposite('user').should == 'group'
    @group.accttype_opposite.should == 'user'
  end

  it '#users raise an error when called on user model' do
    expect { @user.users }.to raise_error(RuntimeError, "Cannot call method 'users' on an Account of type 'user'")
  end

  it '#users return empty array when called on group' do
    @group.users.should be_empty
  end

  it '#groups raise an error when called on group model' do
    expect { @group.groups }.to raise_error(RuntimeError, "Cannot call method 'groups' on an Account of type 'group'")
  end

  it '#groups returns empty array when called on user model' do
    @user.groups.should be_empty
  end

  it '#add_user and #users' do
    @group.add_user(@user).should_not be_empty
    # should not add new user if the user already exist in @group
    @group.add_user(@user).should be_empty
    @group.users.should include(@user)
  end

end
