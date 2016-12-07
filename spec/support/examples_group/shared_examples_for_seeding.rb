shared_examples_for ".seed called multiple times" do |count = 1|
  it ".seed called multiple times" do
    3.times { described_class.seed }
    expect(described_class.count).to eq(count)
  end
end

shared_examples_for "seeding users with" do |klasses|
  let(:users) { {'admin' => 'super_administrator' } }

  it "seeds users #{klasses.present? ? 'with' : ''} #{klasses.collect(&:to_s).join(', ')}" do
    klasses.push(User)
    klasses.each { |klass| klass.send(:seed) }

    users.each do |userid, role|
      user = User.where(:userid => userid).first
      expect(user).not_to be_nil
      expect(user.userid).to eq(userid)
      if klasses == [MiqUserRole, MiqGroup, User]
        expect(user.current_group.name).to eq("EvmGroup-#{role}")
        expect(user.current_group.miq_user_role_name).to eq("EvmRole-#{role}")
      else
        expect(user.current_group).to be_nil
      end
    end
  end
end
