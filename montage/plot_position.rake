load './Rakefile'

require 'wcs'
require 'pwrake/mcgp'
Pwrake::MCGP.graph_partition('shrunk.jpg')

require './plot_position'
PlotPosition.new.plot

exit
