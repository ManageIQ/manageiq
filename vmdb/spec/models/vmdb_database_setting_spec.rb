require "spec_helper"

describe VmdbDatabaseSetting do
  before :each do
    @db = FactoryGirl.create(:vmdb_database)
  end

  it 'has database settings' do
    expect(@db.vmdb_database_settings.length).to be > 0
    @db.vmdb_database_settings.each do |setting|
      expect(setting.vmdb_database).to eql(@db)
    end
  end

  it 'can find settings' do
    settings = VmdbDatabaseSetting.all
    expect(settings.length).to be > 0
  end

  it 'sets a default database' do
    setting = VmdbDatabaseSetting.new
    expect(setting.vmdb_database).to eql(@db)
  end

  [
    :name,
    :description,
    :value,
    :minimum_value,
    :maximum_value,
    :unit,
    :vmdb_database_id
  ].each do |field|
    it "has a #{field}" do
      setting = VmdbDatabaseSetting.all.first
      expect(setting.send(field)).to be
    end
  end
end
