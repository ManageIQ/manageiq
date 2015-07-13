module MiqTimer
    
    def self.time()
        t0 = Time.new
        yield
        t1 = Time.new
        return(t1 - t0)
    end
    
end # module MiqTimer

if $0 == __FILE__
    pwd = ""
    et = MiqTimer.time do
        pwd = `pwd`
        sleep 25
    end
    puts "pwd = #{pwd}"
    puts "et = #{et}"
end
