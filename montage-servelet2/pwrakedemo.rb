require 'socket'

require './graph.rb'
require './graph_part.rb'

begin
  MUTEX = Mutex.new
  SOCKET = TCPSocket.open("localhost", 13391)
  END{SOCKET.close}
rescue
end

Pwrake.manager.scheduler_class.module_eval do

  def on_task_start(t)
    return unless t.kind_of?(Rake::FileTask)
    fn = t.name
    if $g and tag = $g.tasknode_id[fn]
      hid = "%02d" % ($g.get_host_id||0)
      MUTEX.synchronize do
        #puts "start #{hid} #{tag}"
        SOCKET.puts("start #{hid} #{tag}") if defined? SOCKET
      end
    end
  end

  def on_task_end(t)
    return unless t.kind_of?(Rake::FileTask)
    fn = t.name
    if $g
      if tag = $g.tasknode_id[fn]
        hid = "%02d" % ($g.get_host_id||0)
        MUTEX.synchronize do
          #puts "end #{hid} #{tag}"
          SOCKET.puts("end #{hid} #{tag}") if defined? SOCKET
        end
      end
      if tag = $g.filenode_id[fn]
        hid = $g.get_gfwhere_id(fn)
        #puts "hid=#{hid}"
        hid = "%02d" % (hid||0)
        MUTEX.synchronize do
          #puts "end #{hid} #{tag}"
          SOCKET.puts("end #{hid} #{tag}") if defined? SOCKET
        end
      end
    end
    #
    res = fn
    shrink = 10
    case fn
    when /\.fits$/
      if /\.t\.fits$/!~fn and fn!="shrunk.fits" and File.exist?(fn)
        jpg = fn.sub(/\.fits$/,'.jpg')
        if /\.s\.fits$/=~fn
          sfits = fn
        else
          sfits = fn.sub(/\.fits$/,'.sfits')
          sh "mShrink #{fn} #{sfits} #{shrink}"
        end
        sh "mJPEG -ct 0 -gray #{sfits} -0.1s '99.8%' gaussian -out #{jpg}" do |*a| end
        sh "rm #{sfits}" if fn != sfits
        res = "img #{fn}"
      end
    when /\.jpg$/
      if File.exist?(fn)
        res = "img #{fn}"
      end
    end
    MUTEX.synchronize do
      #puts res
      SOCKET.puts(res) if defined? SOCKET
    end
  end

end # Pwrake.manager.scheduler_class

TMPFILES=[]

def show_graph
  puts "show_graph!!!!!!!!!!!!!"
  $g = Pwrake::Graphviz.new
  $g.trace
  $g.write("/tmp/graph.dot")
  system 'dot -T svg -Eweight=1 -Gstylesheet="pwrakedemo.css" -o /tmp/graph0.svg /tmp/graph.dot'

  s = File.read("/tmp/graph0.svg")
  s.gsub!(/<g ([^>]*\bclass="([^"]*)"[^>]*)><title>([^<]*)<\/title>(.*?)<\/g>/m) do |l|
    a = $1
    b = $2
    t = $3
    e = $4
    m = ''
    if b == "node"
      a.sub!(/\bid="([^"]*)"/, %[id="#{t}"])
      e.sub!(/<(polygon|ellipse)([^>]*) fill="none"([^>]*)>/, '<\1\2\3>')
      e.sub!(/<text /, '<text fill="black" ')

      if name = $g.node_name[t]
        task = Rake.application[name]
        if task.prerequisites.empty?
          c = "input"
        elsif task.already_invoked
          c = "done"
        else
          c = "yet"
        end
        e.sub!(/<(polygon|ellipse) /, "<\\1 class='#{c}' ")
      end
      m = 'onmouseover="nodeIn(evt);" onmouseout="nodeOut(evt);" '
    elsif b == "cluster"
      e.sub!(/<(polygon) /, "<\\1 class='#{t}' ")
      e.sub!(/ stroke="([^"]*)"/, "")
    end
    "<g #{m}#{a}><title>#{t}</title>#{e}</g>"
  end
#
#  s.gsub!(/<g ([^>]*\bclass="([^"]*)"[^>]*)><title>([^<]*)<\/title>(.*?)<\/g>/m) do |l|
#    a = $1
#    b = $2
#    t = $3
#    e = $4
#    a.sub!(/\bid="([^"]*)"/, %[id="#{t}"])
#    e.sub!(/<(polygon|ellipse)([^>]*) fill="none"([^>]*)>/, '<\1\2\3>')
#    e.sub!(/<text /, '<text fill="black" ')
#
#    if name = $g.node_name[t]
#      task = Rake.application[name]
#      if task.prerequisites.empty?
#        c = "input"
#      elsif task.already_invoked
#        c = "done"
#      else
#        c = "yet"
#      end
#      e.sub!(/<(polygon|ellipse) /, "<\\1 class='#{c}' ")
#      %[<g onmouseover="nodeIn(evt);" onmouseout="nodeOut(evt);" #{a}><title>#{t}</title>#{e}</g>]
#    elsif /^cluster(\d+)/ =~ t
#      c = $1
#      e.sub!(/<polygon /, "<\\1 class='cluster#{c}' ")
#      %[<g #{a}><title>#{t}</title>#{e}</g>]
#    end
#  end
#
  File.open("/tmp/graph.svg","w") do |w|
    w.write s
    w.close
  end

  MUTEX.synchronize do
    SOCKET.puts("reload") if defined? SOCKET
  end
end
