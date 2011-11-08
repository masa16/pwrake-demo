# from test8.rb

require "~/2011/ruby-metis/ext/metis"
#require "~/2011/ruby-wcs/ext/wcstools"
require "pwrake/affinity.rb"


Pwrake.manager.scheduler_class.module_eval do

  alias on_start_orig on_start
  def on_trace(tasks)
  #def on_start
    if Pwrake.manager.gfarm and Pwrake.manager.affinity and !$graph
      hosts = Pwrake.manager.core_list.sort.uniq
      puts "-- hosts=#{hosts}"
      t1 = Time.now
      g = Pwrake::MetisGraph.new(hosts)
      g.trace("default")
      g.part_graph
      g.set_part
      t2 = Time.now
      Pwrake::Log.log "Time for TOTAL Graph Partitioning: #{t2-t1} sec"
      #if ENV["REP"]=="on"
      #  g.init_gfrep(tasks)
      #end
      if ENV["GRAPH"]=="on"
        #g.gnuplot
        g.graphviz_part("wf.dot")
        exit
      end
      $graph = true
      show_graph
    end
    tasks
  end

end # Pwrake.manager.scheduler_class.module_eval


module Pwrake

  class MetisGraph

    load "color.rb"

    #def initialize(tasks,hosts)
      # @tasks = tasks
    def initialize(hosts)
      @hosts = hosts
      @n_part = @hosts.size
      @traced = {}

      @edges = []

      @vertex_name2id = {}
      @vertex_id2name = []
      @vertex_depth = {}

      @count = 0

      @depth_hist = []

      @gviz_nodes = []
      @gviz_edges = []
      @edge_list = []
    end


    #def gfwhere
    #  filenames = []
    #  @tasks.each do |t|
    #    if t.kind_of? Rake::FileTask and prereq = t.prerequisites
    #      filenames.concat(prereq)
    #    end
    #  end
    #  filenames = filenames.sort.uniq
    #  @gfwhere_result = GfarmSSH.gfwhere(filenames)
    #  #puts "gfwhere_result="
    #  #p @gfwhere_result
    #end


    def trace( name = "default", target = nil )
      #target_orig = target
      traced_cond = @traced[name]

      #puts "taskname=#{name}"

      task = Rake.application[name]

      if task.kind_of?(Rake::FileTask) and task.prerequisites.size > 0
        push_vertex( name )
        push_edge( name, target )
        target = name
      end

      @traced[name] = true

      if !traced_cond
        depth = 0

        task.prerequisites.each do |prereq|
          d = trace( prereq, target )
          depth = d if d and d > depth
        end

        if task.kind_of?(Rake::FileTask) and task.prerequisites.size > 0
          depth += 1
          hist = @depth_hist[depth] || 0
          @depth_hist[depth] = hist + 1
        end

        @vertex_depth[name] = depth
      end

      return @vertex_depth[name]
    end

    def trim( name )
      name = name.to_s
      name = File.basename(name)
      name.sub(/H\d+/,'').sub(/object\d+/,"")
    end

    def push_vertex( name )
      if @vertex_name2id[name].nil?
        @vertex_name2id[name] = @count
        @vertex_id2name[@count] = name

        tag = "T#{@count}"
        @gviz_nodes[@count] = "#{tag} [label=\"#{trim(name)}\", shape=box, style=filled, fillcolor=\"%s\"];"

        @count += 1
      end
    end

    def push_edge( name, target )
      if target
        v1 = @vertex_name2id[name]
        v2 = @vertex_name2id[target]
        (@edges[v1] ||= []).push v2
        (@edges[v2] ||= []).push v1

        @gviz_edges.push "T#{v1} -> T#{v2};"
        @edge_list.push [v1,v2]
      end
    end

    def part_graph
      @xadj = [0]
      @adjcny = []
      @vwgt = []
      map_depth = []
      uvb = []
      c = 0
      @depth_hist.each do |x|
        if x and x>=@n_part
          map_depth << c
          c += 1
          uvb << 1 + 2.0*@n_part/x
          #uvb << ((x >= @n_part) ? 1.05 : 1.5)
        else
          map_depth << nil
        end
      end

      Pwrake::Log.log @depth_hist.inspect
      Pwrake::Log.log [c, map_depth].inspect
      Pwrake::Log.log uvb.inspect

      #return if c==0

      @count.times do |i|
        @adjcny.concat(@edges[i].sort) if @edges[i]
        @xadj.push(@adjcny.size)

        depth = @vertex_depth[@vertex_id2name[i]]
        w = Array.new(c,0)
        if j = map_depth[depth]
          w[j] = 1
        end
        @vwgt.push(w)
        #p [@vertex_id2name[i],w]
      end
      [@xadj, @adjcny, @vwgt]

      t1 = Time.now
      tpw = Array.new(@n_part,1.0/@n_part)
      sum = 0.0; tpw.each{|x| sum+=x}
      if false
        puts "@xadj.size=#{@xadj.size}"
        puts "@adjcny.size/2=#{@adjcny.size/2}"
        puts "tpw.sum=#{sum}"
        puts "@xadj=#{@xadj.inspect}"
        puts "@adjcny=#{@adjcny.inspect}"
        puts "@vwgt=#{@vwgt.inspect}"
      end
      @part = Metis.mc_part_graph_recursive2(c, @xadj,@adjcny, @vwgt,nil, tpw)
      #@part = Metis.mc_part_graph(c,@xadj,@adjcny, @vwgt,nil, [1.03]*c, @n_part)
      #@part = Metis.mc_part_graph_kway(c,@xadj,@adjcny, @vwgt,nil, [1.05]*c, @n_part)
      #@part = Metis.mc_part_graph_kway(c,@xadj,@adjcny, @vwgt,nil, uvb, @n_part)
      t2 = Time.now
      Pwrake::Log.log "Time for Graph Partitioning: #{t2-t1} sec"
      #p @part
    end

    def set_part
      puts "@part = #{@part.inspect}"
      @vertex_id2name.each_with_index do |name,idx|
        i_part = @part[idx]
        host = @hosts[i_part-1]
        task = Rake.application[name]
        task.locality = [host]
        puts "name=#{name}, idx=#{idx}, i_part=#{i_part}, host=#{host}"
        puts "task=#{task.inspect}, i_part=#{i_part}, host=#{host}"
      end
    end

    def init_gfrep(tasks)
      path = Pathname.new(Dir.pwd)
      while ! path.mountpoint?
        path = path.parent
      end
      top = path
      gfdir = Pathname.new(Dir.pwd).relative_path_from(top).to_s
      #puts "gfdir=#{gfdir}"

      t1 = Time.now
      #files = []
      #tasks.each do |t|
      #  files.concat(t.prerequisites)
      #end
      #files = files.sort.uniq
      rep_map = {}
      tasks.each do |t|
        #files.each do |name|
        name = t.name
        preq = t.prerequisites
        idx = @vertex_name2id[name]
        #p [idx,name,preq]
        i_part = @part[idx]
        rep_map[i_part] ||= []
        #rep_map[i_part].push(name)
        rep_map[i_part].concat(preq)
      end
      rep_map.each do |i_part,files|
        files.sort!
        files.uniq!
        files.map!{|f| gfdir+'/'+f}
        host = @hosts[i_part]
        cmd="gfrep -m -N 1 -D #{host} "+files.join(" ")
        Pwrake::Log.log cmd
        system cmd
      end
      t2 = Time.now
      Pwrake::Log.log "Time for replication: #{t2-t1} sec"
    end


    def part=(pg)
      @part=pg
    end

    def p_vertex
      @count.times do |i|
        if @vertex_weight[i] > 0
          puts "#{@vertex_weight[i]} #{@part[i]} #{@vertex_names[i]}"
        end
      end
    end


    def read_coord(hdr_file)
      h = {}
      open(hdr_file) do |f|
        while l=f.gets
          h[$1] = $2 if /(\w+)\s*=\s*'?([^'\s]+)'?/ =~ l
        end
      end
      crval1 = h['CRVAL1'].to_f
      crpix1 = h['CRPIX1'].to_f
      cdelt1 = h['CDELT1'].to_f
      naxis1 = h['NAXIS1'].to_i
      crval2 = h['CRVAL2'].to_f
      crpix2 = h['CRPIX2'].to_f
      cdelt2 = h['CDELT2'].to_f
      naxis2 = h['NAXIS2'].to_i
      crota  = h['CROTA2'].to_f
      ctype1 = h['CTYPE1']
      ctype2 = h['CTYPE2']
      equinox = h['EQUINOX'].to_i
      epoch = 2000

      wcs = Wcstools.wcskinit(
      naxis1, # /* Number of pixels along x-axis */
      naxis2, # /* Number of pixels along y-axis */
      ctype1, # /* FITS WCS projection for axis 1 */
      ctype2, # /* FITS WCS projection for axis 2 */
      crpix1, # /* Reference pixel coordinates */
      crpix2, # /* Reference pixel coordinates */
      crval1, # /* Coordinate at reference pixel in degrees */
      crval2, # /* Coordinate at reference pixel in degrees */
      nil,    # /* Rotation matrix, used if not NULL */
      cdelt1, # /* scale in degrees/pixel, if cd is NULL */
      cdelt2, # /* scale in degrees/pixel, if cd is NULL */
      crota,  # /* Rotation angle in degrees, if cd is NULL */
      equinox,# /* Equinox of coordinates, 1950 and 2000 supported */
      epoch)  # /* Epoch of coordinates, for FK4/FK5 conversion */

      co = []
      co << Wcstools.pix2wcs(wcs,1,1)
      co << Wcstools.pix2wcs(wcs,naxis1,1)
      co << Wcstools.pix2wcs(wcs,naxis1,naxis2)
      co << Wcstools.pix2wcs(wcs,1,naxis2)
      co << co[0]
      co << []
      co
    end

    def gnuplot
      ### Gnuplot
      img_tbl = Montage.read_image_tbl(INPUT_DIR+"/rimages.tbl")

      fitspos = []
      centpos = []
      # @part.each{|x| fitspos[x]=[]}
      ra_max = -360
      ra_min = 360
      dec_max = -90
      dec_min = 90

      @vertex_id2name.each_with_index do |tn,idx|
        if /^p\// =~ tn
          #p [idx,@part[idx],tn]
          img_tbl.each do |row|
            if tn.to_s.include?(row["fname"])
              naxis1 = row['naxis1'].to_i
              crval1 = row['crval1'].to_f
              crpix1 = row['crpix1'].to_f
              cdelt1 = row['cdelt1'].to_f
              ctype1 = row['ctype1']
              naxis2 = row['naxis2'].to_i
              crval2 = row['crval2'].to_f
              crpix2 = row['crpix2'].to_f
              cdelt2 = row['cdelt2'].to_f
              ctype2 = row['ctype2']
              crota  = row['crota2'].to_f
              equinox = row['equinox'].to_i
              epoch = 2000
              wcs = Wcstools.wcskinit(
              naxis1, # /* Number of pixels along x-axis */
              naxis2, # /* Number of pixels along y-axis */
              ctype1, # /* FITS WCS projection for axis 1 */
              ctype2, # /* FITS WCS projection for axis 2 */
              crpix1, # /* Reference pixel coordinates */
              crpix2, # /* Reference pixel coordinates */
              crval1, # /* Coordinate at reference pixel in degrees */
              crval2, # /* Coordinate at reference pixel in degrees */
              nil,    # /* Rotation matrix, used if not NULL */
              cdelt1, # /* scale in degrees/pixel, if cd is NULL */
              cdelt2, # /* scale in degrees/pixel, if cd is NULL */
              crota,  # /* Rotation angle in degrees, if cd is NULL */
              equinox,# /* Equinox of coordinates, 1950 and 2000 supported */
              epoch)  # /* Epoch of coordinates, for FK4/FK5 conversion */

              co = []
              co << Wcstools.pix2wcs(wcs,1,1)
              co << Wcstools.pix2wcs(wcs,naxis1,1)
              co << Wcstools.pix2wcs(wcs,naxis1,naxis2)
              co << Wcstools.pix2wcs(wcs,1,naxis2)
              co << co[0]
              co << []
              ra,dec = Wcstools.pix2wcs(wcs,(1+naxis1)*0.5,(1+naxis2)*0.5)
              width = cdelt1.abs * naxis1
              height = cdelt2.abs * naxis2

              i = @part[idx]

              centpos << [i,ra,dec]

              fitspos[i] ||= []
              fitspos[i].concat(co)

              ra1 = ra-width
              ra2 = ra+width
              dec1 = dec-height
              dec2 = dec+height
              ra_max = ra2 if ra_max < ra2
              ra_min = ra1 if ra_min > ra1
              dec_max = dec2 if dec_max < dec2
              dec_min = dec1 if dec_min > dec1
            end
          end
        end
      end

      tilepos = []
      Dir.glob('t/tile_*.hdr') do |hdr_file|
        tilepos.concat( read_coord(hdr_file) )
      end

      gp_lines = []
      color = COLOR * ((@n_part-1)/COLOR.size+1)
      open("fitspos.dat","w") do |w|
        c = 0
        fitspos.each_with_index do |v,i|
          if v
            v.each do |xy|
              w.puts xy.join(" ")
            end
            gp_lines << " 'fitspos.dat' index #{c} w line lc rgb '#{color[i]}' lt 1 lw 0.3 title ''"
            c += 1
          else
            puts "missing data part=#{i}"
            #w.puts "999 999"
            #w.puts "1000 1000"
            #w.puts("\n")
          end
          w.puts("\n\n")
        end
        gp_lines << " 'fitspos.dat' index #{c} w line lc rgb 'black' lt 1 lw 0.3 title ''"

        tilepos.each do |xy|
          w.puts xy.join(" ")
        end
        w.puts("\n\n")
      end

      puts "writing plot.gpl"
      open("plot.gpl","w") do |w|
        w.puts "
set terminal postscript eps linewidth 2 dashlength 3 font 22 size 10in,8in
set output 'pos.eps'
set xlabel 'Right Ascension (degree)'
set ylabel 'Declination (degree)'
set xrange [#{ra_max}:#{ra_min}]
set yrange [#{dec_min}:#{dec_max}]
set key outside
"
        centpos.each do |x|
          w.puts "set label '#{x[0]}' at #{x[1]},#{x[2]} center tc rgb '#{color[x[0]]}'"
        end

        #a = []
        #b = []

        ##@n_part.times do |i|
        #fitspos.each_with_index do |v,i|
        #  if v
        #    a.push " 'fitspos.dat' index #{i} w filledcurve fill solid 0.3 lc rgb '#{COLOR[i]}' lt 1 lw 0 title '##{i}'"
        #    b.push " 'fitspos.dat' index #{i} w line lc rgb '#{COLOR[i]}' lt 1 lw 0.3 title ''"
        #  end
        #end
        #b.push " 'fitspos.dat' index #{@n_part} w line lc rgb 'black' lt 1 lw 0.3 title ''"
        #w.puts (a+b).join(",\\\n")

        w.puts "plot \\"
        w.puts gp_lines.join(",\\\n")
      end

      system "gnuplot plot.gpl"
    end


    def graphviz(file)
      open(file, "w") do |w|
        #w.puts "digraph sample {\ngraph [size=\"12,100\",ranksep=1.5,nodesep=0.2];"
        w.puts "digraph sample {"
        w.puts "graph [size=\"70,70\", rankdir=LR];"
        @gviz_nodes.each_with_index do |x,i|
          x = x % COLOR[@part[i]]
          w.puts x
        end
        @gviz_edges.each do |x|
          w.puts x
        end
        w.puts "}"
      end
    end


    def graphviz_part(file)
      n_depth = @depth_hist.size
      open(file, "w") do |w|
        #w.puts "digraph sample {\ngraph [size=\"12,100\",ranksep=1.5,nodesep=0.2];"
        w.puts "digraph sample {"
        w.puts "graph [size=\"70,70\", rankdir=LR, concentrate=true];"

        color = COLOR * ((@n_part-1)/COLOR.size+1)

        @n_part.times do |part|
          w.puts "subgraph cluster#{part+1} {"
          depth = Array.new(n_depth){[]}

          @vertex_id2name.each_with_index do |x,i|
            if @part[i] == part
              w.puts "#{i} [label=\"#{trim(x)}\",shape=box,style=filled,fillcolor=\"#{COLOR[@part[i]]}\"];"
              depth[@vertex_depth[x]].push i
            end
          end

          ranks = (1..n_depth).map{|i| "R#{part}_#{i}"}
          ranks.each do |x|
              w.puts x+' [shape=plaintext,label="",fixedsize=true,width=0,height=0];'
          end
          w.puts ranks.join(" -> ")+' [arrowhead=none,penwidth=0,color=white];'

          depth.each_with_index do |a,i|
            a.unshift ranks[i]
            w.puts "{rank=same; #{a.join(';')}}"
          end
          w.puts "}"
        end

        @edge_list.each do |v1,v2|
          w.puts "#{v1} -> #{v2};"
        end
        w.puts "}"
      end
    end

  end # class MetisGraph

end
