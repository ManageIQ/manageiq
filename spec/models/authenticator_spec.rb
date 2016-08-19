describe Authenticator do
  describe '.for' do
    it "instantiates the matching class" do
      expect(Authenticator.for(:mode => 'database')).to be_a(Authenticator::Database)
      expect(Authenticator.for(:mode => 'ldap')).to be_a(Authenticator::Ldap)
      expect(Authenticator.for(:mode => 'ldaps')).to be_a(Authenticator::Ldap)
      expect(Authenticator.for(:mode => 'amazon')).to be_a(Authenticator::Amazon)
      expect(Authenticator.for(:mode => 'httpd')).to be_a(Authenticator::Httpd)
    end

    it "always uses local DB for admin" do
      expect(Authenticator.for({:mode => 'database'}, 'admin')).to be_a(Authenticator::Database)
      expect(Authenticator.for({:mode => 'ldap'}, 'admin')).to be_a(Authenticator::Database)
      expect(Authenticator.for({:mode => 'httpd'}, 'admin')).to be_a(Authenticator::Database)
    end
  end

  describe '#authorize' do
    let(:authenticator) { Authenticator::Httpd.new({}) }
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:task) { FactoryGirl.create(:miq_task) }
    let(:groups) { FactoryGirl.create_list(:miq_group, 2) }

    it 'Updates the user groups when no matching groups' do
      expect(authenticator).to receive(:find_external_identity)
        .and_return([{:username => user.userid, :fullname => user.name}, []])

      authenticator.authorize(task.id, user.userid)
      expect(user.reload.miq_groups).to be_empty
    end

    it 'Updates the user groups' do
      expect(authenticator).to receive(:find_external_identity)
        .and_return([{:username => user.userid, :fullname => user.name}, groups.collect(&:name)])

      authenticator.authorize(task.id, user.userid)
      expect(user.reload.miq_groups).to match_array(groups)
    end
  end
end
