require "spec_helper"

describe "DatabaseConfiguration patch" do
  before(:each) do
    Rails.stub(:env => ActiveSupport::StringInquirer.new("production"))

    @app = Vmdb::Application.new
    @app.config.paths["config/database"] = "does/not/exist" # ignore real database.yml
  end

  context "ERB in the template" do
    before(:each) do
      @tempfile = Tempfile.new('yml').tap do |f|
        f.write database_config
        f.close
      end
      @app.config.paths["config/database"].unshift @tempfile.path
    end

    let(:database_config) { "---\nvalue: <%= 1 %>\n" }

    it "doesn't execute" do
      expect(@app.config.database_configuration).to eq('value' => '<%= 1 %>')
    end
  end

  context "when DATABASE_URL is set" do
    around(:each) do |example|
      begin
        old_env = ENV.delete('DATABASE_URL')
        ENV['DATABASE_URL'] = 'postgres://'
        example.run
      ensure
        # ENV['x'] = nil deletes the key because ENV accepts only string values
        ENV['DATABASE_URL'] = old_env
      end
    end

    it "ignores a missing file" do
      expect(@app.config.database_configuration).to eq({})
    end
  end

  context "with no source of configuration" do
    it "explains the problem" do
      begin
        old = ENV.delete('DATABASE_URL')
        expect { @app.config.database_configuration }.to raise_error(/Could not load database configuration/)
      ensure
        # ENV['x'] = nil deletes the key because ENV accepts only string values
        ENV['DATABASE_URL'] = old
      end
    end
  end
end
