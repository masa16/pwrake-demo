load './Rakefile'

require 'wcs'
require 'pwrake/mcgp2'
Pwrake::MCGP.graph_partition('shrunk.jpg')

require './plot_position'
PlotPosition.new.plot

exit
