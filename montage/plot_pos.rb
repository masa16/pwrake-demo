require 'wcs'
require './montage_tools'

class PlotPos

  def plot(imgtbl,outfile)
    fitspos(imgtbl)
    minmax
    write(outfile)
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

  def fitspos(imgtbl)
    img_tbl = Montage.read_image_tbl(imgtbl)
    @fitspos = img_tbl.map do |row|
      naxis1 = row['naxis1'].to_i
      naxis2 = row['naxis2'].to_i
      wcs = get_wcs(row)
      [
        wcs.pix2wcs(1,1),
        wcs.pix2wcs(naxis1,1),
        wcs.pix2wcs(naxis1,naxis2),
        wcs.pix2wcs(1,naxis2)
      ]
    end
  end

  def minmax
    @ra_max = -360
    @ra_min = 360
    @dec_max = -90
    @dec_min = 90
    @fitspos.each do |co|
      co.each do |c|
        ra = c[0]
        @ra_max = ra if @ra_max < ra
          @ra_min = ra if @ra_min > ra
        dec = c[1]
        @dec_max = dec if @dec_max < dec
        @dec_min = dec if @dec_min > dec
      end
    end
    ra_pad = (@ra_max - @ra_min)*0.01
    @ra_max += ra_pad
    @ra_min -= ra_pad
    dec_pad = (@dec_max - @dec_min)*0.01
    @dec_max += dec_pad
    @dec_min -= dec_pad
  end

  def write(outfile)
    case outfile
    when /\.png$/
      term = "set terminal png small size 640,480"
    when /\.eps$/
      term = "set terminal postscript eps linewidth 2 dashlength 3 font 22 size 10in,8in"
    else
      raise "Output file should be an EPS or PNG file"
    end

    puts "writing #{outfile}"
    IO.popen("gnuplot","r+") do |w|
      w.puts term
      w.puts "
set output '#{outfile}'
set xlabel 'Right Ascension (degree)'
set ylabel 'Declination (degree)'
set xrange [#{@ra_max}:#{@ra_min}]
set yrange [#{@dec_min}:#{@dec_max}]
set key outside

plot '-' w line lc rgb 'red' lt 1 lw 0.3 title ''"

      @fitspos.each do |rect|
        rect.each do |xy|
          w.puts xy.join(" ")
        end
        w.puts rect[0].join(" ")
        w.puts ""
      end
      w.puts("end\n")
    end
  end
end


if __FILE__ == $0
  if ARGV.size != 2
    print "usage:\n\n    ruby #{$0} images.tbl pos.[eps|png]\n\n"
  end
  PlotPos.new.plot(ARGV[0]||"images.tbl", ARGV[1]||"pos.eps")
end
