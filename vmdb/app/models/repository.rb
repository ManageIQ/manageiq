class Repository < ActiveRecord::Base
  belongs_to :storage

  validates_presence_of     :name, :relative_path
  validates_uniqueness_of   :name

  before_save       :save_storage
  before_validation :set_relative_path, :on => :create

  acts_as_miq_taggable
  include ReportableMixin

  include MiqPolicyMixin
  include FilterableMixin
  include AsyncDeleteMixin

  def self.add(name, path)
    storage_name, relative_path, type = parse_path(path)

    #Allow to fail and raise exception to caller if an entry already exists for name
    repository = self.new(:name => name, :relative_path => relative_path)
    repository.path = path
    repository.save!
    repository
  end

  def enforce_policy(vm, event)
    inputs = {:vm => vm, :repository => self}
    # Policy.enforce_policy(self, vm, event, inputs)
    MiqEvent.raise_evm_event(vm, event, inputs)
  end

  def scan
    #For now we'll use the first host (lowest id)
    host = Host.find(:first, :order => :id)
    host.scan_repository(self)
  end

  def path
    @path ||= begin
      if storage_id.blank?
        self.relative_path
      else
        case storage.store_type
        when "VMFS"
          "[#{storage.name}] #{relative_path}"
        when "NFS"
          "[#{storage.name}] #{relative_path}"
        else
          File.join(storage.name, relative_path)
        end
      end
    end
  end

  def path=(newpath)
    @path = newpath
  end

  def vms
    if relative_path != "/"
      Vm.all(:conditions => ["storage_id=? and location like ?", storage_id, relative_path + "%"])
    else
      Vm.all(:conditions => ["storage_id=?", storage_id])
    end
  end

  def miq_templates
    if relative_path != "/"
      MiqTemplate.all(:conditions => ["storage_id=? and location like ?", storage_id, relative_path + "%"])
    else
      MiqTemplate.all(:conditions => ["storage_id=?", storage_id])
    end
  end

  def self.valid_path?(path)
    begin
      storage_name, relative_path, type = Repository.parse_path(path)
    rescue => err
      return false
    end
    return true, type
  end

  def self.parse_path(path)
    path.gsub!(/\\/, "/")
    if path.starts_with? "//"
      raise "path, '#{path}', is malformed" unless path =~ %r{^//[^/].*/.+$}
      type = "NAS"
    else
      if path.starts_with? "["
        raise "path, '#{path}', is malformed"  unless path =~ %r{^\[[^\]].+\].*$}
        type = "VMFS"
      else
        raise "path, '#{path}', is malformed"
        #type = "local"
      end
    end

    case type
    when "NAS"
      #path is a UNC
      storage_name = path.split("/")[0..3].join("/")
      relative_path = ""
      relative_path = path.split("/")[4..path.length].join("/") if path.length > 4
    when "VMFS"
      #path is a VMWare storage name
      /^\[(.*)\](.*)$/ =~ path
      storage_name = $1
      relative_path = $2.strip
      relative_path.sub!(/^\//, '') # Some esx servers add a leading "/". This needs to be striped off to allow matching on location
    when "LOCAL"
      #path is a regular file path
      storage_name = ""
      relative_path = path
    end
    relative_path = "/" if relative_path == ""

    return storage_name, relative_path, type
  end

  private

  def set_relative_path
    dummy, self.relative_path, dummy = Repository.parse_path(path) unless path.nil?
  end

  def save_storage
    storage_name, self.relative_path, type = Repository.parse_path(path)
    storage = Storage.find_by_name(storage_name)
    storage = Storage.create(:name => storage_name, :store_type => type) if storage == nil

    self.storage_id = storage.id
  end
end
