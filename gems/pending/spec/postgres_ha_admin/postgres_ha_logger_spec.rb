require 'postgres_ha_admin/postgres_ha_logger'

describe PostgresHaAdmin::PostgresHaLogger do
  let(:dummy_class) do
    clazz = Dummy.new
    clazz.init_logger(Rails.root.join("log"))
    clazz
  end

  after do
    if File.exist?(dummy_class.log_file)
      File.delete(dummy_class.log_file)
    end
  end

  describe "#log_info" do
    it "writes 'info' message to log file" do
      message = "Testing 'log_info' on ha logger"
      dummy_class.log_info(message)
      expect(File.read(dummy_class.log_file)).to include message
    end
  end

  describe "#log_error" do
    it "writes 'error' message to log file" do
      message = "Testing 'log_info' on ha logger"
      dummy_class.log_info(message)
      expect(File.read(dummy_class.log_file)).to include message
    end
  end

  class Dummy
    include PostgresHaAdmin::PostgresHaLogger
  end
end
