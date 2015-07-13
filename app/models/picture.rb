class Picture < ActiveRecord::Base
  has_one :binary_blob, :as => :resource, :dependent => :destroy, :autosave => true
  include ReportableMixin

  URL_ROOT          = Rails.root.join("public").to_s
  DEFAULT_DIRECTORY = File.join(URL_ROOT, "pictures")
  Dir.mkdir(DEFAULT_DIRECTORY) unless File.directory?(DEFAULT_DIRECTORY)

  def self.atStartup
    require 'fileutils'
    pattern = File.join(directory, "*")
    FileUtils.rm Dir.glob(pattern)
  end

  def self.directory
    @directory || DEFAULT_DIRECTORY
  end

  def self.directory=(value)
    dir = File.join(URL_ROOT, url_path(value, URL_ROOT))
    Dir.mkdir(dir) unless File.directory?(dir)
    @directory = dir
  end

  def self.url_path(filename, basepath = URL_ROOT)
    abs_filename = File.absolute_path(filename)
    abs_basepath = File.absolute_path(basepath)

    if abs_filename.starts_with?(abs_basepath)
      abs_filename[abs_basepath.length..-1]
    else
      abs_filename
    end
  end

  def content
    self.binary_blob.try(:binary)
  end

  def content=(value)
    self.binary_blob ||= BinaryBlob.new
    self.binary_blob.binary = value
  end

  def size
    self.content.try(:length).to_i
  end

  def md5
    self.binary_blob.try(:md5)
  end

  def extension
    self.binary_blob.try(:data_type)
  end

  def extension=(value)
    self.binary_blob ||= BinaryBlob.new
    self.binary_blob.data_type = value
  end

  def self.sync_to_disk(pictures)
    pictures = pictures.to_miq_a unless pictures.kind_of?(Array)
    pictures.each do |pic|
      pic = Picture.find(pic) if pic.kind_of?(Numeric)
      raise "invalid object: #{pic.inspect}" unless pic.kind_of?(Picture)
      pic.sync_to_disk
    end
  end

  def sync_to_disk
    File.open(filename, "wb") { |fd| fd.write(self.content) } if sync_to_disk?
  end

  def sync_to_disk?
    return true unless File.file?(filename)
    return true if File.size(filename) != size
    return true if Digest::MD5.new.file(filename).hexdigest != md5
    return false
  end

  def basename
    @basename ||= begin
      raise "must have a numeric id" unless self.id.kind_of?(Numeric)
      "#{self.compressed_id}.#{extension}"
    end
  end

  def filename
    @filename ||= File.join(self.class.directory, basename)
  end

  def url_path(basepath = URL_ROOT)
    self.class.url_path(self.filename, basepath)
  end
end
