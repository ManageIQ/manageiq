describe MiqRequestMixin do
  let(:test_class) do
    Class.new do
      attr_accessor :options, :userid
      include MiqRequestMixin

      def initialize
        @options = {}
      end
    end
  end

  let(:test_instance) { test_class.new }

  it "#get_user only searches users in the current region" do
    user = FactoryBot.create(:user, :userid => "TestUser")
    FactoryBot.create(:user, :userid => "TestUser", :id => ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1))

    test_instance.userid = "TestUser"
    expect(test_instance.get_user).to eq(user)
  end
end
