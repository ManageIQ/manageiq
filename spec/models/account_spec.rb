RSpec.describe Account do
  let(:user_account1) { FactoryBot.create(:account_user) }
  let(:group_account1) { FactoryBot.create(:account_group) }

  context 'when host has users and groups' do
    let(:host) { FactoryBot.create(:host) }
    let(:test_xml) do
      REXML::Document.new("<miq>
                          <accounts>
                          <users><user name='test_user'/></users>
                          <groups><group name='test_group'/></groups>
                          </accounts>
                          </miq>")
    end

    it '.add_elements' do
      user_account1.class.add_elements(host, test_xml)
      expect(host.users.exists?(:name => 'test_user')).to be_truthy
      expect(host.groups.exists?(:name => 'test_group')).to be_truthy
    end
  end

  it '#accttype_opposite' do
    expect(group_account1.accttype_opposite).to eq('user')
    expect(user_account1.accttype_opposite).to eq('group')
  end

  describe '#users' do
    context 'when called on a user account' do
      it 'raises an error' do
        expect { user_account1.users }.to raise_error(
          RuntimeError, "Cannot call method 'users' on an Account of type 'user'"
        )
      end
    end
    context 'when called on a group account' do
      it 'returns an empty array' do
        expect(group_account1.users).to be_empty
      end
    end
  end

  describe '#groups' do
    context 'when called on a group account' do
      it 'raises an error' do
        expect { group_account1.groups }.to raise_error(
          RuntimeError, "Cannot call method 'groups' on an Account of type 'group'"
        )
      end
    end
    context 'when called on a user account' do
      it 'returns an empty array' do
        expect(user_account1.groups).to be_empty
      end
    end
  end

  describe 'group methods' do
    let(:user_account2) { FactoryBot.create(:account_user) }

    it '#add_user' do
      expect(group_account1.add_member(user_account1)).not_to be_empty
      expect(group_account1.add_member(user_account2)).not_to be_empty
      # should not add new user if the user already exist in group_account1
      expect(group_account1.add_member(user_account1)).to be_empty
      expect(group_account1.members).to include(user_account1, user_account2)
    end

    it '#remove_user' do
      expect(group_account1.add_member(user_account1)).not_to be_empty
      expect(group_account1.remove_member(user_account1)).not_to be_empty
      expect(group_account1.members).not_to include(user_account1)
    end

    it '#remove_all_users' do
      expect(group_account1.add_member(user_account1)).not_to be_empty
      expect(group_account1.add_member(user_account2)).not_to be_empty
      expect(group_account1.remove_all_members).not_to be_empty
      expect(group_account1.members).not_to include(user_account1, user_account2)
    end
  end

  describe 'user methods' do
    let(:group_account2) { FactoryBot.create(:account_group) }

    it '#add_group' do
      expect(user_account1.add_member(group_account1)).not_to be_empty
      expect(user_account1.add_member(group_account2)).not_to be_empty
      # should not add new group if the group already exist in user_account1
      expect(user_account1.add_member(group_account1)).to be_empty
      expect(user_account1.members).to include(group_account1, group_account2)
    end

    it '#remove_group' do
      expect(user_account1.add_member(group_account1)).not_to be_empty
      expect(user_account1.remove_member(group_account1)).not_to be_empty
      expect(user_account1.members).not_to include(group_account1)
    end

    it '#remove_all_groups' do
      expect(user_account1.add_member(group_account1)).not_to be_empty
      expect(user_account1.add_member(group_account2)).not_to be_empty
      expect(user_account1.remove_all_members).not_to be_empty
      expect(user_account1.members).not_to include(group_account1, group_account2)
    end
  end
end
