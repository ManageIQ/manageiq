class Picture < ApplicationRecord
  validates :content, :presence => true
  validates :extension,
            :presence  => true,
            :inclusion => { :in => %w(png jpg svg), :message => 'must be a png, jpg, or svg' }

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

  def self.create_from_base64(attributes = {})
    attributes = attributes.with_indifferent_access
    new(attributes.except(:content)).tap do |picture|
      picture.content = Base64.strict_decode64(attributes[:content].to_s)
      picture.save!
    end
  end

  def content=(value)
    value.force_encoding('ASCII-8BIT')
    super(value).tap { self.md5 = Digest::MD5.hexdigest(value) }
  end

  def size
    content.try(:length).to_i
  end

  def basename
    @basename ||= begin
      raise _("must have a numeric id") unless id.kind_of?(Numeric)
      "#{id}.#{extension}"
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
