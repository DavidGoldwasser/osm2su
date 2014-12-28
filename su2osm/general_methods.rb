# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'

module Sketchup::Su2osm

  def self.setup_layers_for_background_merge

      puts ""
      puts ">>Setting expected layers for merge to background OSM"

      # get SketchUp model and entities
      skp_model = Sketchup.active_model
      entities = skp_model.active_entities

      # create layers matched to OpenStudio surface group types
      layers = skp_model.layers
      new_layer = layers.add("su2osm - SiteShadingGroup")
      new_layer = layers.add("su2osm - BuildingAndSpaceShadingGroup")
      new_layer = layers.add("su2osm - Space")
      new_layer = layers.add("su2osm - InteriorPartitionSurfaceGroup")

  end

end # module Sketchup::Su2osm
