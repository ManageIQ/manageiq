module MiqReeGc
  def self.print_gc_info_on_signal(stats = false, signal = :SIGALRM)
    # Tell a process to print it's stats:
    #   kill -s SIGALRM 10491
    # Tell all rubies to print their stats:
    #   killall ruby -s SIGALRM
    if GC && GC.respond_to?(:enable_stats)
      GC.enable_stats if stats == true

      Signal.trap(signal) do
        STDERR.puts("ObjectSpace.statistics:\n#{ObjectSpace.statistics}")
        STDERR.puts("GC.dump:\n")
        GC.dump

        STDERR.puts("ObjectSpace.live_objects:      #{ObjectSpace.live_objects}\n")
        STDERR.puts("ObjectSpace.allocated_objects: #{ObjectSpace.allocated_objects}\n")

        # These require the stats are enabled
        if $enable_gc_stats
          STDERR.puts("GC.collections:                #{GC.collections}\n")
          STDERR.puts("GC.time(microseconds):         #{GC.time}\n")
          STDERR.puts("GC.allocated_size(bytes):      #{GC.allocated_size}\n")
          STDERR.puts("GC.num_allocations:            #{GC.num_allocations}\n")
          STDERR.puts("GC.growth(bytes):              #{GC.growth}\n")
          GC.clear_stats
        end
        STDERR.puts()
        STDERR.flush
      end
    end
  end
end

