describe ManageIQ::Providers::Amazon::CloudManager::RefreshParser do
  let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  subject { described_class.new(ems, Settings.ems_refresh.ec2) }

  context "#get_public_images" do
    it "applies filter from settings.yml" do
      filter = {:filters => [{:name => "image-type", :values => ["machine"]}]}
      expect(subject).to receive(:get_images)
      expect(subject.instance_variable_get(:@aws_ec2).client)
        .to receive(:describe_images).with(hash_including(filter)).and_return({})
      subject.send(:get_public_images)
    end
  end
end
