RSpec.describe "ar_base extension" do
  context "with a test class" do
    let(:test_class) do
      Class.new(ActiveRecord::Base) do
        def self.name; "TestClass"; end
      end
    end

    it ".vacuum" do
      expect(test_class.connection).to receive(:vacuum_analyze_table).and_return(double(:result_status => 1))
      test_class.vacuum
    end

    it "#postgresql_ssl_friendly_base_reconnect creates new pool/connection objects across models" do
      old_ar_connection, old_ar_pool = ActiveRecord::Base.connection.object_id, ActiveRecord::Base.connection_pool.object_id
      expect(old_ar_connection).to eq(test_class.connection.object_id)
      expect(old_ar_pool).to eq(test_class.connection_pool.object_id)

      test_class.send(:postgresql_ssl_friendly_base_reconnect)

      new_ar_connection, new_ar_pool = ActiveRecord::Base.connection.object_id, ActiveRecord::Base.connection_pool.object_id
      expect(old_ar_connection).not_to eq(new_ar_connection)
      expect(old_ar_pool).not_to eq(new_ar_pool)
      expect(new_ar_connection).to eq(test_class.connection.object_id)
      expect(new_ar_pool).to eq(test_class.connection_pool.object_id)
    end
  end
end
