# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'
require 'su2osm/trans_osm2su.rb'
require 'su2osm/general_methods.rb'
require 'su2osm/geometry.rb'
require 'su2osm/trans_su2osm.rb'
require 'su2osm/config.rb'

module Sketchup::Su2osm

  # Add some menu items to access this
  plugins_menu = UI.menu("Plugins")
  su2osm_menu = plugins_menu.add_submenu($exStrings.GetString("su2osm"))
  su2osm_menu.add_item($exStrings.GetString("Create Layers used by su2osm")) { setup_layers_for_background_merge }
  su2osm_menu.add_item($exStrings.GetString("Import OSM file as SketchUp Groups")) { import_osm_file_as_sketchup_groups }
  su2osm_menu.add_item($exStrings.GetString("Create SketchUp Groups From Diagram")) { create_sketchup_groups_from_diagram }
  su2osm_menu.add_item($exStrings.GetString("Project Loose Geometry Onto SketchUp Groups")) { project_loose_geoemtry_onto_sketchup_groups }
  su2osm_menu.add_item($exStrings.GetString("Merge SketchUp Groups to OSM File")) { merge_sketchup_groups_to_osm_file }
  su2osm_menu.add_item($exStrings.GetString("Set Path to OpenStudio")) { set_path_to_openstudio }

end # module Sketchup::Su2osm