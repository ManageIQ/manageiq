require 'ezcrypto'
require 'encryption/CryptString'
require 'base64'
require 'yaml'

class MiqPassword
  CURRENT_VERSION = "2"
  REGEXP = /v([0-9]+):\{([^}]*)\}/
  REGEXP_START_LINE = /^#{REGEXP}/

  attr_reader :encStr

  def initialize(str = nil)
    return unless str

    @encStr = encrypt(str)
  end

  def encrypt(str)
    encrypt_version_2(str)
  end

  def decrypt(str)
    if str.nil? || str.empty?
      str
    else
      ver, enc = self.class.split(str)
      return "" if enc.empty?

      ver ||= "0" # if we don't know what it is, just assume legacy

      decrypt_method = "decrypt_version_#{ver}"
      raise "unknown encryption version, '#{ver}'" if ver.nil? || !self.respond_to?(decrypt_method, true)
      raise "no encryption key v#{ver}_key" unless self.class.send("v#{ver}_key")

      send(decrypt_method, enc)
    end
  end

  def recrypt(str)
    return str if str.nil? || str.empty?
    decrypted_str =
      begin
        decrypt(str)
      rescue
        source_version = self.class.split(str).first || "0"
        if source_version == "0" # it probably wasn't encrypted
          return str
        else
          raise "not decryptable string"
        end
      end
    encrypt(decrypted_str)
  end

  def self.encrypt(str)
    new.encrypt(str) if str
  end

  def self.decrypt(str)
    new.decrypt(str)
  end

  def self.encrypted?(str)
    !!split(str).first
  end

  def self.md5crypt(str)
    cmd = "openssl passwd -1 -salt \"miq\" \"#{try_decrypt(str)}\""
    `#{cmd}`.split("\n").first
  end

  def self.sysprep_crypt(str)
    Base64.encode64("#{try_decrypt(str)}AdministratorPassword".encode("UTF-16LE")).delete("\n")
  end

  def self.sanitize_string(s)
    s.gsub(REGEXP, '********')
  end

  def self.sanitize_string!(s)
    s.gsub!(REGEXP, '********')
  end

  def self.try_decrypt(str)
    encrypted?(str) ? decrypt(str) : str
  end

  def self.try_encrypt(str)
    encrypted?(str) ? str : encrypt(str)
  end

  # @returns [ver, enc]
  def self.split(encrypted_str)
    if encrypted_str.nil? || encrypted_str.empty?
      [nil, encrypted_str]
    else
      if encrypted_str =~ REGEXP_START_LINE
        [$1, $2]
      elsif legacy = extract_erb_encrypted_value(encrypted_str)
        if legacy =~ REGEXP_START_LINE
          [$1, $2]
        else
          ["0", legacy]
        end
      else
        [nil, encrypted_str]
      end
    end
  end

  def self.key_root
    @@key_root ||= ENV["KEY_ROOT"]
  end

  def self.key_root=(key_root)
    clear_keys
    @@key_root = key_root
  end

  def self.clear_keys
    @@v2_key = @v1_key = @v0_key = nil
  end

  def self.all_keys
    [v2_key] + legacy_keys
  end

  def self.v2_key
    @@v2_key ||= ez_load("v2_key") || begin
      key_file = File.expand_path("v2_key", key_root)
      msg = <<-EOS
#{key_file} doesn't exist!
On an appliance, it should be generated on boot by evmserverd.

If you're a developer, you can copy the #{key_file}.dev to #{key_file}.

Caution, using the developer key will allow anyone with the public developer key to decrypt the two-way
passwords in your database.
EOS
      Kernel.warn msg
    end
  end

  def self.legacy_keys
    [v1_key, v0_key].compact
  end

  def self.add_legacy_key(filename, type = :v1)
    case type
    when :v0
      @v0_key = ez_load(filename, false)
    when :v1
      @v1_key = ez_load(filename)
    end
  end

  class << self
    attr_accessor :v0_key
    attr_accessor :v1_key

    def v2_key=(key)
      @@v2_key = key
    end
  end

  def self.generate_symmetric(filename = nil)
    EzCrypto::Key.generate(:algorithm => "aes-256-cbc").tap do |key|
      key.store(filename) if filename
    end
  end

  protected

  def self.ez_load(filename, recent = true)
    return filename if filename.respond_to?(:decrypt64)
    filename = File.expand_path(filename, key_root)
    if !File.exist?(filename)
      nil
    elsif recent
      EzCrypto::Key.load(filename)
    else
      params = YAML.load_file(filename)
      CryptString.new(nil, params[:algorithm], params[:key], params[:iv])
    end
  end

  def encrypt_version_2(str)
    return "v2:{}" if str.nil? || str.empty?
    "v2:{#{self.class.v2_key.encrypt64(str).chomp.gsub("\n", "")}}"
  end

  def encrypt_version_1(str)
    return "v1:{}" if str.nil? || str.empty?
    "v1:{#{self.class.v1_key.encrypt64(str).chomp}}"
  end

  def decrypt_version_2(str)
    self.class.v2_key.decrypt64(str)
  end

  def decrypt_version_1(str)
    self.class.v1_key.decrypt64(str)
  end

  def decrypt_version_0(str)
    self.class.v0_key.decrypt64(str)
  end

  def self.extract_erb_encrypted_value(value)
    return $1 if value =~ /\A<%= (?:MiqPassword|DB_PASSWORD)\.decrypt\(['"]([^'"]+)['"]\) %>\Z/
  end
end

# Backward compatibility for the class that used to be used by Rails.
DB_PASSWORD = MiqPassword
