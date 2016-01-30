describe Account do
  before(:each) do
    @user = FactoryGirl.create(:account_user)
    @group = FactoryGirl.create(:account_group)
  end

  it '#accttype_opposite' do
    expect(@user.class.accttype_opposite('user')).to eq('group')
    expect(@group.accttype_opposite).to eq('user')
  end

  it '#users raise an error when called on user model' do
    expect { @user.users }.to raise_error(RuntimeError, "Cannot call method 'users' on an Account of type 'user'")
  end

  it '#users return empty array when called on group' do
    expect(@group.users).to be_empty
  end

  it '#groups raise an error when called on group model' do
    expect { @group.groups }.to raise_error(RuntimeError, "Cannot call method 'groups' on an Account of type 'group'")
  end

  it '#groups returns empty array when called on user model' do
    expect(@user.groups).to be_empty
  end

  it '#add_user and #users' do
    expect(@group.add_user(@user)).not_to be_empty
    # should not add new user if the user already exist in @group
    expect(@group.add_user(@user)).to be_empty
    expect(@group.users).to include(@user)
  end
end
