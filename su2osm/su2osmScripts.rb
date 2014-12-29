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
  file_mgt = su2osm_menu.add_submenu($exStrings.GetString("File Management"))
  modeling_tools = su2osm_menu.add_submenu($exStrings.GetString("Modeling Tools"))
  rendering_editable = su2osm_menu.add_submenu($exStrings.GetString("Render Modes - Editable"))
  rendering_infered = su2osm_menu.add_submenu($exStrings.GetString("Render Modes - Infered"))
  prefs = su2osm_menu.add_submenu($exStrings.GetString("Preferences"))

  # add file management menu items
  file_mgt.add_item($exStrings.GetString("Import OSM file as SketchUp Groups")) { import_osm_file_as_sketchup_groups }
  file_mgt.add_item($exStrings.GetString("Merge SketchUp Groups to OSM File")) { merge_sketchup_groups_to_osm_file }

  # add modeling tools menu items
  modeling_tools.add_item($exStrings.GetString("Create Layers used by su2osm")) { setup_layers_for_background_merge }
  modeling_tools.add_item($exStrings.GetString("Create SketchUp Groups From Diagram")) { create_sketchup_groups_from_diagram }
  modeling_tools.add_item($exStrings.GetString("Project Loose Geometry Onto SketchUp Groups")) { project_loose_geoemtry_onto_sketchup_groups }

  # add editable render modes menu items
  rendering_editable.add_item($exStrings.GetString("Clear Render Mode")) { clear_render_mode }  # should turn everything white
  rendering_editable.add_item($exStrings.GetString("Render by Space Type")) { render_by_space_type }
  rendering_editable.add_item($exStrings.GetString("Render by Thermal Zone")) { render_by_thermal_zone }
  rendering_editable.add_item($exStrings.GetString("Render by Building Story")) { render_by_building_story }

  # add infered render modes menu items (things like render by air loop or design load EPD)
  rendering_infered.add_item($exStrings.GetString("Render by Air Loop")) { render_by_air_loop }
  rendering_infered.add_item($exStrings.GetString("Render by Lighting Power Density")) { render_by_lpd }

  # add items for preferences
  prefs.add_item($exStrings.GetString("Set Path to OpenStudio")) { set_path_to_openstudio }

end # module Sketchup::Su2osm