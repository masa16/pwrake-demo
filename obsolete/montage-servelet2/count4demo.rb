class Count4Demo

  def initialize
    reset
  end

  def reset
    @count_local = 0
    @count_remote = 0
    @size_local = 0
    @size_remote = 0
  end

  attr_reader :count_local, :count_remote

  def count(task)
    task_host = Thread.current[:connection].host
    preq = task.prerequisites
    file_hosts = Pwrake::GfarmSSH.gfwhere(preq)
    file_hosts.each do |k,v|
      puts "GfarmSSH.mountpoint=#{Pwrake::GfarmSSH.mountpoint},k=#{k},v=#{v}"
      sz = File.size(Pwrake::GfarmSSH.mountpoint+k)
      if v.any?{|x| x==task_host}
        @count_local += 1
        @size_local += sz
      else
        @count_remote += 1
        @size_remote += sz
      end
    end
  end

  def status
    n = @size_local + @size_remote
    ratio_local = 100.0*@size_local/n
    ratio_remote = 100.0*@size_remote/n
    "stat FileAccess: total %s kB / local %s kB (%5.1f%%) / remote %s kB (%5.1f%%)" %
      [comma(n/1000),comma(@size_local/1000),ratio_local,comma(@size_remote/1000),ratio_remote]
     # [comma(n),comma(@count_local),ratio_local,comma(@count_remote),ratio_remote]
  end

  def comma(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

end
