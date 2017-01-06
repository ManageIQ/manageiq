class Picture < ApplicationRecord
  has_one :binary_blob, :as => :resource, :dependent => :destroy, :autosave => true

  validates :extension,
            :inclusion => { :in => %w(png jpg svg), :message => 'must be a png, jpg, or svg' },
            :if        => :extension

  virtual_has_one :image_href, :class_name => "String"

  URL_ROOT          = Rails.root.join("public").to_s
  DEFAULT_DIRECTORY = File.join(URL_ROOT, "pictures")
  FileUtils.mkdir_p(DEFAULT_DIRECTORY)

  def self.directory
    @directory || DEFAULT_DIRECTORY
  end

  def self.directory=(value)
    dir = File.join(URL_ROOT, url_path(value, URL_ROOT))
    FileUtils.mkdir_p(dir)
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
    binary_blob.try(:binary)
  end

  def content=(value)
    self.binary_blob ||= BinaryBlob.new
    self.binary_blob.binary = value
  end

  def size
    content.try(:length).to_i
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

  def basename
    @basename ||= begin
      raise _("must have a numeric id") unless id.kind_of?(Numeric)
      "#{compressed_id}.#{extension}"
    end
  end

  def filename
    @filename ||= File.join(self.class.directory, basename)
  end

  def url_path(basepath = URL_ROOT)
    self.class.url_path(filename, basepath)
  end

  def image_href
    url_path
  end
end
