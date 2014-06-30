class PlotPosition

  COLOR = %w[
    #ff0000
    #00c000
    #0080ff
    #c000ff
    #00eeee
    #c04000
    #c8c800
    #4169e1
    #ffc020
    #008040
    #c080ff
    #306080
    #8b0000
    #408000
    #ff80ff
    #7fffd4
    #a52a2a
    #ffff00
    #40e0d0
    #f03232
    #90ee90
    #add8e6
    #f055f0
    #e0ffff
    #eedd82
    #ffb6c1
    #afeeee
    #ffd700
    #00ff00
    #006400
    #00ff7f
    #228b22
    #2e8b57
    #0000ff
    #00008b
    #191970
    #000080
    #0000cd
    #87ceeb
    #00ffff
    #ff00ff
    #00ced1
    #ff1493
    #ff7f50
    #f08080
    #ff4500
    #fa8072
    #e9967a
    #f0e68c
    #bdb76b
    #b8860b
    #f5f5dc
    #a08020
    #ffa500
    #ee82ee
    #9400d3
    #dda0dd
    #905040
    #556b2f
    #801400
    #801414
    #804014
    #804080
    #8060c0
    #8060ff
    #808000
    #ff8040
    #ffa040
    #ffa060
    #ffa070
    #ffc0c0
    #ffff80
    #ffffc0
    #cdb79e
    #f0fff0
    #a0b6cd
    #c1ffc1
    #cdc0b0
    #7cff40
    #a0ff20
  ]
  %w[
    aliceblue
    antiquewhite
    aquamarine
    azure
    beige
    bisque
    black
    blanchedalmond
    blue
    blueviolet
    brown
    burlywood
    cadetblue
    chartreuse
    chocolate
    coral
    cornflowerblue
    cornsilk
    crimson
    cyan
    darkgoldenrod
    darkgreen
    darkkhaki
    darkolivegreen
    darkorange
    darkorchid
    darksalmon
    darkseagreen
    darkslateblue
    darkslategray
    darkslategrey
    darkturquoise
    darkviolet
    deeppink
    deepskyblue
    dimgray
    dimgrey
    dodgerblue
    firebrick
    floralwhite
    forestgreen
    gainsboro
    ghostwhite
    gold
    goldenrod
  ]

  def initialize
    @n_part = Pwrake.application.host_list.group_hosts.size
  end

  def plot
    fitspos
    minmax
    write
  end


  def get_wcs(row)
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
    Wcs::WorldCoor.new(
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
  end

  def print_host_id
    @hosts_kv.keys.sort.each do |host|
      printf "%d,%s\n",@hosts_kv[host],host
    end
  end

  def fitspos
    ### Gnuplot
    img_tbl = Montage.read_image_tbl("images.tbl")
    @fitspos = []
    @centpos = []
    @hosts_kv = {}

    img_tbl.each do |row|
      pimg = 'p/'+row['fname']
      tsk = Rake.application[pimg]
      @hosts_kv[tsk.suggest_location[0]] = true
    end

    @hosts_kv.keys.sort.each_with_index do |host,i|
      @hosts_kv[host] = i
    end

    img_tbl.each do |row|
      naxis1 = row['naxis1'].to_i
      naxis2 = row['naxis2'].to_i
      pimg = 'p/'+row['fname']
      tsk = Rake.application[pimg]
      group_id = tsk.group_id || 0
      host = tsk.suggest_location[0]
      host_id = @hosts_kv[host]
      wcs = get_wcs(row)
      co = [
        wcs.pix2wcs(1,1),
        wcs.pix2wcs(naxis1,1),
        wcs.pix2wcs(naxis1,naxis2),
        wcs.pix2wcs(1,naxis2)
      ]
      @fitspos[host_id] ||= []
      @fitspos[host_id] << co
      cp = wcs.pix2wcs((1+naxis1)*0.5,(1+naxis2)*0.5) + [group_id,host_id,host]
      @centpos << cp
    end
    print_host_id
  end

  def minmax
    @ra_max = -360
    @ra_min = 360
    @dec_max = -90
    @dec_min = 90
    @fitspos.each do |cg|
      cg.each do |co|
        co.each do |c|
          ra = c[0]
          @ra_max = ra if @ra_max < ra
          @ra_min = ra if @ra_min > ra
          dec = c[1]
          @dec_max = dec if @dec_max < dec
          @dec_min = dec if @dec_min > dec
        end
      end
    end
  end

  def write
    gp_lines = []
    color = COLOR * ((@n_part-1)/COLOR.size+1)
    open("fitspos.dat","w") do |w|
      c = 0
      @fitspos.each_with_index do |v,i|
        if v
          v.each do |rect|
            rect.each do |xy|
              w.puts xy.join(" ")
            end
            w.puts rect[0].join(" ")
            w.puts ''
          end
          gp_lines << " 'fitspos.dat' index #{c} w line lc rgb '#{color[i]}' lt 1 lw 0.3 title ''"
          c += 1
        else
          puts "missing data part=#{i}"
        end
        w.puts("\n\n")
      end
      #gp_lines << " 'fitspos.dat' index #{c} w line lc rgb 'black' lt 1 lw 0.3 title ''"
      #w.puts("\n\n")
    end

    puts "writing plot.gpl"
    open("plot.gpl","w") do |w|
      w.puts "
  set terminal postscript eps linewidth 2 dashlength 3 font 22 size 10in,8in
  set output 'pos.eps'
  set xlabel 'Right Ascension (degree)'
  set ylabel 'Declination (degree)'
  set xrange [#{@ra_max}:#{@ra_min}]
  set yrange [#{@dec_min}:#{@dec_max}]
  set key outside
  "
      @centpos.each do |x|
        if x[4]
          w.puts "set label '#{x[2]}:#{x[3]}' at #{x[0]},#{x[1]} center font \"Times,20\" tc rgb '#{color[x[3]]}'"
          #w.puts "set label '#{x[2]}' at #{x[0]},#{x[1]} center"
        end
      end

      w.puts "plot \\"
      w.puts gp_lines.join(",\\\n")
    end

    #system "gnuplot plot.gpl"
  end

end


task "plot_position" do
  require 'wcs'
  require 'pwrake/mcgp2'
  Pwrake::MCGP.graph_partition('shrunk.jpg')
  PlotPosition.new.plot
end
