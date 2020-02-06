RSpec.describe ExternalUrlMixin do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; 'TestClass'; end
      self.table_name = 'vms'
      include ExternalUrlMixin
    end
  end

  describe '#external_url=' do
    before do
      User.current_user = FactoryBot.create(:user)
    end

    let(:test_instance) do
      test_class.create.tap { |i| i.external_url = 'https://www.other.example.com' }
    end

    it 'sets url for the current user' do
      expect(ExternalUrl.where(
        :user          => User.current_user,
        :resource_type => 'TestClass',
        :resource_id   => test_instance.id
      ).first.attributes).to include(
        'url' => 'https://www.other.example.com',
      )
    end

    it 'removes previously set url for the current user' do
      test_instance.external_url = 'https://www.example.com'
      test_instance.reload
      expect(test_instance.external_urls.count).to eq(1)

      expect(ExternalUrl.where(
        :user          => User.current_user,
        :resource_type => 'TestClass',
        :resource_id   => test_instance.id
      ).first.attributes).to include(
        'url' => 'https://www.example.com',
      )
    end
  end
end
