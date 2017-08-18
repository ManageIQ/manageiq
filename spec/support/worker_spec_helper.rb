module WorkerSpecHelper
  def self.setup_worker_dir_metadata(config)
    escaped_path = Regexp.compile('spec[\\\/]workers[\\\/]')
    config.define_derived_metadata(:file_path => escaped_path) do |metadata|
      metadata[:type] ||= :worker
    end
  end

  def run_single_worker_bin
    Rails.root.join("lib", "workers", "bin", "run_single_worker.rb")
  end
end
