require 'postgres_ha_admin/database_yml'

describe PostgresHaAdmin::DatabaseYml do
  let(:yml_utils) { described_class.new(@yml_file.path, 'test') }

  before do
    @yml_file = Tempfile.new('database.yml')
    yml_data = YAML.load('---
      base: &base
        username: user
        wait_timeout: 5
        port:
      test: &test
        <<: *base
        pool: 3
        database: vmdb_test'
                        )
    File.write(@yml_file.path, yml_data.to_yaml)
  end

  after do
    @yml_file.close(true)
  end

  describe "#pg_params_from_database_yml" do
    it "returns pg connection parameters based on 'database.yml'" do
      params = yml_utils.pg_params_from_database_yml
      expect(params).to eq(:dbname => 'vmdb_test', :user => 'user')
    end
  end

  describe "#update_database_yml" do
    it "back-up existing 'database.yml'" do
      original_yml = YAML.load_file(@yml_file)

      new_name = yml_utils.update_database_yml(:any => 'any')

      expect(new_name.size).to be > @yml_file.path.size
      expect(YAML.load_file(new_name)).to eq original_yml
    end

    it "takes hash with 'pg style' parameters and override database.yml" do
      yml_utils.update_database_yml(:dbname => 'some_db', :host => "localhost", :port => '')
      yml = YAML.load_file(@yml_file)

      expect(yml['test']).to eq('database' => 'some_db', 'host' => 'localhost',
                                'username' => 'user', 'pool' => 3, 'wait_timeout' => 5)
    end
  end
end
