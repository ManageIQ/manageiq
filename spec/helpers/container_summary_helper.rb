describe ContainerSummaryHelper do
  REL_HASH_WITH_LINK = [:label, :image, :value, :link, :title]
  REL_HASH_WITHOUT_LINK = [:label, :image, :value]

  let(:container_project) { FactoryGirl.create(:container_project) }
  before do
    self.class.send(:include, ApplicationHelper)

    @record = FactoryGirl.build(:container_group, :container_project => container_project)

    login_as @user = FactoryGirl.create(:user)
  end

  context ".textual_container_project" do
    subject { textual_container_project }

    it 'show link when role allows' do
      allow(@user).to receive(:role_allows?).and_return(true)

      expect(subject.keys).to eq(REL_HASH_WITH_LINK)
      expect(subject[:value]).to eq(container_project.name)
    end

    it 'hide link when role does not allow' do
      allow(@user).to receive(:role_allows?).and_return(false)

      expect(subject.keys).to eq(REL_HASH_WITHOUT_LINK)
      expect(subject[:value]).to eq(container_project.name)
    end
  end

  context ".textual_containers" do
    before  { 2.times { FactoryGirl.create(:container, :container_group => @record) } }
    subject { textual_containers }

    it 'show link when role allows' do
      allow(@user).to receive(:role_allows?).and_return(true)

      expect(subject.keys).to eq(REL_HASH_WITH_LINK)
      expect(subject[:value]).to eq("2")
    end

    it 'hide link when role does not allow' do
      allow(@user).to receive(:role_allows?).and_return(false)

      expect(subject.keys).to eq(REL_HASH_WITHOUT_LINK)
      expect(subject[:value]).to eq("2")
    end
  end
end
