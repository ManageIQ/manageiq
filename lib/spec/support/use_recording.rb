require 'openssl' # Required for 'Digest' in camcorder (< Ruby 2.1)?
require 'camcorder'

module Camcorder
  def self.recordings_dir
    @record_dir ||= File.join(spec_dir, 'recordings')
  end

  def self.recording_for(id)
    idyml = id + (id[-4..-1] == '.yml' ? '' : '.yml')
    File.expand_path(File.join(recordings_dir, idyml))
  end

  def self.recorder_for(recording_id)
    Camcorder::Recorder.new(recording_for(recording_id))
  end

  def self.intercept(cls, *methods)
    @intercepted_constructors ||= []
    @intercepted_constructors << cls

    Camcorder.intercept_constructor(cls) do
      methods_with_side_effects(*methods)
    end
  end

  def self.deintercept_all
    @intercepted_constructors.each { |cls| Camcorder.deintercept_constructor(cls) }
    @intercepted_constructors = []
  end

  def self.use_recording(recording)
    Camcorder.config.recordings_dir = recordings_dir
    Camcorder.default_recorder      = recorder_for(recording)

    Camcorder.default_recorder.transaction do
      yield

      deintercept_all
    end
  end
end
