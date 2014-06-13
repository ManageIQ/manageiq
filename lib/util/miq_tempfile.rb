require 'delegate'
require 'tempfile'

class MiqTempfile < DelegateClass(Tempfile)
  # TODO: share this definition with appliance console code.
  MIQ_TMP_DIR = '/var/www/miq_tmp'.freeze

  def initialize(basename, *options)
    if File.directory?(MIQ_TMP_DIR)
      super(Tempfile.new(basename, MIQ_TMP_DIR, *options))
    else
      super(Tempfile.new(basename, *options))
    end
  end
end
