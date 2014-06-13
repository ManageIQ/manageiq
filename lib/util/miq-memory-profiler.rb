#
#  Scott Laird - scott@sigkill.org
#  http://code.google.com/p/ruby-memory-profiler/
#
#  Modified 2009 ManageIQ, Inc.
#

class MiqMemoryProfiler
  DEFAULTS = {:delay => 10, :string_debug => false}

  def initialize(opt={})
    @opt = DEFAULTS.dup.merge(opt)

    @prev = Hash.new(0)
    @curr = Hash.new(0)
    @curr_strings = []
    @delta = Hash.new(0)

    @file = File.open("memory_profiler.log.#{Process.pid}",'w')
  end

  def profile
    begin
      GC.start
      @curr.clear

      @curr_strings = [] if @opt[:string_debug]

      ObjectSpace.each_object do |o|
        @curr[o.class] += 1 #Marshal.dump(o).size rescue 1
        if @opt[:string_debug] and o.class == String
          @curr_strings.push o
        end
      end

      if @opt[:string_debug]
        File.open("memory_profiler_strings.log.#{Time.now.to_i}",'w') do |f|
          @curr_strings.sort.each do |s|
            f.puts s
          end
        end
        @curr_strings.clear
      end

      @delta.clear
      (@curr.keys + @delta.keys).uniq.each do |k,v|
        @delta[k] = @curr[k]-@prev[k]
      end

      @file.puts "Top 20"
      @delta.sort_by { |k,v| -v.abs }[0..19].sort_by { |k,v| -v}.each do |k,v|
        @file.printf "%+7d: %s (%d)\n", v, k.name, @curr[k] unless v == 0
      end
      @file.flush

      @delta.clear
      @prev.clear
      @prev.update @curr
      GC.start
    rescue Exception => err
      STDERR.puts "** memory_profiler error: #{err}"
    end
  end

  def self.start(opt={})
    opt = DEFAULTS.dup.merge(opt)
    m = self.new(opt)

    Thread.new do
      loop do
        m.profile
        sleep opt[:delay]
      end
    end
  end
end