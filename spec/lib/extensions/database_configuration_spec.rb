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
      old_env, ENV['DATABASE_URL'] = ENV['DATABASE_URL'], 'postgres://'
      example.run
      ENV['DATABASE_URL'] = old_env
    end

    it "ignores a missing file" do
      expect(@app.config.database_configuration).to eq({})
    end
  end

  context "with no source of configuration" do
    it "explains the problem" do
      expect { @app.config.database_configuration }.to raise_error(/Could not load database configuration/)
    end
  end
end
