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
    expect(setting.vmdb_database).to eq(@db)
  end

  it 'aliases min_val to minimum_value' do
    setting = VmdbDatabaseSetting.where('min_val is not null').first
    expect(setting.min_val).to eq(setting.minimum_value)
  end

  it 'aliases max_val to maximum_value' do
    setting = VmdbDatabaseSetting.where('max_val is not null').first
    expect(setting.max_val).to eq(setting.maximum_value)
  end

  it 'aliases setting to value' do
    setting = VmdbDatabaseSetting.where('setting is not null').first
    expect(setting.value).to eq(setting.setting)
  end

  it 'combines short_desc and extra_desc for description' do
    setting = VmdbDatabaseSetting.where(:extra_desc => nil).first
    expect(setting.description).to eq(setting.short_desc)

    setting = VmdbDatabaseSetting.where('extra_desc is not null').first
    expect(setting.description).to eq("#{setting.short_desc}  #{setting.extra_desc}")
  end

  it 'defaults unit to a blank string' do
    setting = VmdbDatabaseSetting.where(:unit => nil).first
    expect(setting.unit).to eq("")
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
