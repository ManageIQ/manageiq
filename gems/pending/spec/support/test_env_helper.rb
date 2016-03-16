require 'yaml'
require 'fileutils'
require 'pathname'
require 'vcr'

GEMS_PENDING_ROOT ||= File.expand_path(File.join(__dir__, "../.."))

class TestEnvHelper
  attr_reader :relative_dir, :absolute_recording_dir, :config_file

  SPEC_DIR       = File.join(GEMS_PENDING_ROOT, 'spec')
  SPEC_PATH      = Pathname.new(SPEC_DIR)
  RECORDINGS_DIR = File.join(SPEC_DIR, 'recordings')

  # Set TEST_ENV_DIR environment variable, when recording.
  TEST_ENV_DIR       = ENV['TEST_ENV_DIR'] || File.join(SPEC_DIR, 'test_env')
  CONFIG_DIR         = File.join(TEST_ENV_DIR, 'config')
  GLOBAL_CONFIG_FILE = File.join(TEST_ENV_DIR, 'config.yml')

  def initialize(test_path)
    # <GEMS_PENDING_ROOT>/spec/some_dir1/some_dir2/some_spec.rb
    @test_file     = File.expand_path(test_path)

    # <GEMS_PENDING_ROOT>/spec/some_dir1/some_dir2
    @test_dir      = File.dirname(@test_file)

    # some_spec
    @test_basename = File.basename(@test_file, ".rb")

    # some_dir1/some_dir2/some_spec
    @relative_dir = File.join(spec_relative_path(@test_dir), @test_basename)
    
    # <GEMS_PENDING_ROOT>/spec/recordings/some_dir1/some_dir2
    @absolute_recording_dir = File.join(RECORDINGS_DIR, @relative_dir)

    # <GEMS_PENDING_ROOT>/spec/test_env/config/some_dir1/some_dir2/some_spec.yml
    @config_file = File.join(CONFIG_DIR, "#{@relative_dir}.yml")
  end

  # Global configuration values.
  def self.[](tag)
    global_config_values[tag] || global_config_filter[tag] || global_config_default[tag]
  end

  # Test-local configuration values - can override global.
  def [](tag)
    config_values[tag] || config_filter[tag] || config_default[tag] || self.class[tag]
  end

  #
  # Global configuration.
  #
  def self.global_config
    @global_config ||= begin
      YAML.load_file(GLOBAL_CONFIG_FILE)
    rescue
      {}
    end
  end

  def global_config
    self.class.global_config
  end

  def self.global_config_values
    @global_config_values ||= global_config[:values] || {}
  end

  def global_config_values
    self.class.global_config_values
  end

  def self.global_config_filter
    @global_config_filter ||= global_config[:filter] || {}
  end

  def global_config_filter
    self.class.global_config_filter
  end

  def self.global_config_default
    @global_config_default ||= global_config[:default] || {}
  end

  def global_config_default
    @self.class.global_config_default
  end

  #
  # Test-local configuration.
  #
  def config
    @config ||= begin
      YAML.load_file(@config_file)
    rescue => err
      puts err.to_s
      {}
    end
  end

  def config_values
    @config_values ||= config[:values] || {}
  end

  def config_filter
    @config_filter ||= config[:filter] || {}
  end

  def config_default
    @config_default ||= config[:default] || {}
  end

  #
  # Path and directory methods.
  #
  def cassette_for(id)
    File.join(@relative_dir, "#{@test_basename}#{id}")
  end

  def spec_relative_path(path)
    Pathname.new(File.expand_path(path)).relative_path_from(SPEC_PATH).to_s
  end

  def pwd_relative_path(path)
    self.class.pwd_relative_path(path)
  end

  def self.recordings_dir
    pwd_relative_path(RECORDINGS_DIR)
  end

  def self.pwd_relative_path(path)
    pwd = Pathname.new(Dir.getwd)
    Pathname.new(File.expand_path(path)).relative_path_from(pwd).to_s
  end

  def ensure_recording_dir_exists
    FileUtils.mkdir_p(@absolute_recording_dir)
  end

  #
  # Filter global values.
  #
  def self.vcr_filter(vcr_config)
    global_config_filter.each do |val_tag, replacement_text|
      next unless (value = global_config_values[val_tag])
      vcr_config.filter_sensitive_data(replacement_text) { CGI.escape(value) }
      vcr_config.filter_sensitive_data(replacement_text) { value }
    end
  end

  #
  # Filter test-specific values.
  #
  def vcr_filter
    VCR.configure do |c|
      config_filter.each do |val_tag, replacement_text|
        next unless (value = config_values[val_tag])
        c.filter_sensitive_data(replacement_text) { CGI.escape(value) }
        c.filter_sensitive_data(replacement_text) { value }
      end
    end
  end
end

if __FILE__ == $0
  env = TestEnvHelper.new(__FILE__)
  puts env.global_config.inspect
  puts
  puts env.config.inspect
  puts
  puts "RECORDINGS_DIR         = #{TestEnvHelper::RECORDINGS_DIR}"
  puts "recordings_dir         = #{TestEnvHelper.recordings_dir}"
  puts "absolute_recording_dir = #{env.absolute_recording_dir}"
  puts "relative_dir           = #{env.relative_dir}"
  puts "config_file            = #{env.config_file}"
end
