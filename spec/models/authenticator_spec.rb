RSpec.describe Authenticator do
  describe '.for' do
    it "instantiates the matching class" do
      expect(Authenticator.for(:mode => 'database')).to be_a(Authenticator::Database)
      expect(Authenticator.for(:mode => 'ldap')).to be_a(Authenticator::Ldap)
      expect(Authenticator.for(:mode => 'ldaps')).to be_a(Authenticator::Ldap)
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
    let(:user) { FactoryBot.create(:user_with_group) }
    let(:task) { FactoryBot.create(:miq_task) }
    let(:groups) { FactoryBot.create_list(:miq_group, 2) }

    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it 'Updates the user groups when no matching groups' do
      expect(authenticator).to receive(:find_external_identity)
        .and_return([{:username => user.userid, :fullname => user.name, :domain => "example.com"}, []])

      authenticator.authorize(task.id, user.userid)
      expect(user.reload.miq_groups).to be_empty
    end

    it 'Updates the user groups' do
      expect(authenticator).to receive(:find_external_identity)
        .and_return([{:username => user.userid, :fullname => user.name, :domain => "example.com"}, groups.collect(&:name)])

      authenticator.authorize(task.id, user.userid)
      expect(user.reload.miq_groups).to match_array(groups)
    end
  end

  describe '.match_groups' do
    let(:authenticator) { Authenticator::Httpd.new({}) }

    def create_groups(group_descriptions)
      group_descriptions.each { |d| FactoryBot.create(:miq_group, :description => d) }
    end

    it "returns external groups matching internal ones" do
      create_groups(%w[group1 group2 group3])
      matched_groups = authenticator.send(:match_groups, %w[group2 group4])
      expect(matched_groups.collect(&:description)).to match_array(%w[group2])
    end

    it "matches groups without case sensitivity" do
      create_groups(%w[group1 group2 GROUP3 GROUP4])
      matched_groups = authenticator.send(:match_groups, %w[Group3 Group5])
      expect(matched_groups.collect(&:description)).to match_array(%w[GROUP3])
    end

    it "returns empty list when no groups match" do
      create_groups(%w[group1 group2])
      matched_groups = authenticator.send(:match_groups, %w[group3])
      expect(matched_groups).to be_empty
    end

    it "only returns matched group for the current region" do
      FactoryBot.create(:miq_group,
                        :description => "group2",
                        :id          => ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1))
      FactoryBot.create(:miq_group, :description => "group1")
      group2 = FactoryBot.create(:miq_group, :description => "group2")

      matched_groups = authenticator.send(:match_groups, %w[group2])
      expect(MiqGroup.where(:description => "group2").count).to eq(2)
      expect(matched_groups.count).to             eq(1)
      expect(matched_groups.first.id).to          eq(group2.id)
      expect(matched_groups.first.description).to eq(group2.description)
    end
  end
end
