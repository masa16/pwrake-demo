# Settings
INPUT_DIR    = ENV['INPUT_DIR']    || "r"
INPUT_SUFFIX = ENV['INPUT_SUFFIX'] || "fits"

REGION_HDR = ENV['REGION_HDR'] || INPUT_DIR+"/region.hdr"
SHRUNK_HDR = ENV['SHRUNK_HDR'] || INPUT_DIR+"/shrunken.hdr"
IMAGES_TBL = ENV['IMAGES_TBL'] || "images.tbl"

SHRINK_FACTOR = 10
