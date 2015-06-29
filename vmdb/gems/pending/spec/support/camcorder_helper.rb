require 'camcorder'

Camcorder.config.recordings_dir = File.join(LIB_ROOT, 'spec/recordings')

module Camcorder
  def self.intercept(cls, *methods)
    @intercepted_constructors ||= []
    raise "#{cls} already intercepted" if @intercepted_constructors.include?(cls)
    @intercepted_constructors << cls

    intercept_constructor(cls) do
      methods_with_side_effects(*methods)
    end
  end

  def self.use_recording(name)
    raise "no block given" unless block_given?
    self.default_recorder = recorder_for(name)
    default_recorder.transaction do
      begin
        yield
      ensure
        deintercept_all
      end
    end
  end

  def self.recorder_for(name)
    Recorder.new(File.join(config.recordings_dir, "#{name}.yml"))
  end
  private_class_method :recorder_for

  def self.deintercept_all
    @intercepted_constructors.each { |cls| deintercept_constructor(cls) }
    @intercepted_constructors = []
  end
  private_class_method :deintercept_all
end
