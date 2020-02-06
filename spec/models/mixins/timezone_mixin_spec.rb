RSpec.describe TimezoneMixin do
  let(:test_class) do
    Class.new do
      include TimezoneMixin
    end
  end

  context ".server_timezone" do
    it "server default" do
      expect(MiqServer).to receive(:my_server).and_return(double(:server_timezone => "Eastern Time (US & Canada)"))
      expect(test_class.server_timezone).to eq("Eastern Time (US & Canada)")
    end
  end

  context "with a class instance" do
    let(:test_inst) { test_class.new }

    it "#with_a_timezone in Hawaii" do
      expect(test_inst.with_a_timezone("Hawaii") { Time.zone }.to_s).to eq("(GMT-10:00) Hawaii")
    end

    it "#with_a_timezone in GMT" do
      expect(test_inst.with_a_timezone("UTC") { Time.zone }.to_s).to eq("(GMT+00:00) UTC")
    end

    it "#with_current_user_timezone" do
      EvmSpecHelper.local_miq_server
      expect(test_inst.with_current_user_timezone { Time.zone }.to_s).to eq("(GMT+00:00) UTC")
    end

    context "with a user" do
      let!(:user) do
        User.current_user = FactoryBot.create(:user)
      end

      it "#with_current_user_timezone in GMT" do
        allow(user).to receive(:get_timezone).and_return("UTC")
        expect(test_inst.with_current_user_timezone { Time.zone }.to_s).to eq("(GMT+00:00) UTC")
      end

      it "#with_current_user_timezone in Hawaii" do
        allow(user).to receive(:get_timezone).and_return("Hawaii")
        expect(test_inst.with_current_user_timezone { Time.zone }.to_s).to eq("(GMT-10:00) Hawaii")
      end
    end
  end
end
