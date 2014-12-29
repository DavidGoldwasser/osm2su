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

  # to be used by render modes
  def self.material_hash()
    hash = {}
    materials = Sketchup.active_model.materials
    materials.each { |material|
      hash[material.name] = material
    }

    return hash
  end

  def self.clear_render_mode

    puts ""
    puts ">>Clear Render Mode"

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      surface_group_type = entity.get_attribute 'su2osm', 'surface_group_type'
      next if surface_group_type.to_s != "space" # todo - should probably check layer instead of this
      entity.material = nil # I don't think this will do what I want
    end

    # todo - later I'll need to drill down to surfaces and other groups. I'll also have to do this when I switch between surface vs. space render modes.

  end

  def self.render_by_space_type

    puts ""
    puts ">>Rendering By Space Types"

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      surface_group_type = entity.get_attribute 'su2osm', 'surface_group_type'
      next if surface_group_type.to_s != "space" # todo - should probably check layer instead of this
      space_type_name = entity.get_attribute 'su2osm', 'space_type_name'
      entity.material = material_hash[space_type_name]
    end

  end

  def self.render_by_thermal_zone

    puts ""
    puts ">>Rendering By Thermal Zones"

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      surface_group_type = entity.get_attribute 'su2osm', 'surface_group_type'
      next if surface_group_type.to_s != "space" # todo - should probably check layer instead of this
      thermal_zone_name = entity.get_attribute 'su2osm', 'thermal_zone_name'
      entity.material = material_hash[thermal_zone_name]
    end

  end

  def self.render_by_building_story

    puts ""
    puts ">>Rendering By Building Story"

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      surface_group_type = entity.get_attribute 'su2osm', 'surface_group_type'
      next if surface_group_type.to_s != "space" # todo - should probably check layer instead of this
      building_story_name = entity.get_attribute 'su2osm', 'building_story_name'
      entity.material = material_hash[building_story_name]
    end

  end

  def self.render_by_air_loop

    puts ""
    puts ">>Rendering By Air Loop"

  end

  def self.render_by_lpd

    puts ""
    puts ">>Rendering By Lighting Power Density"

  end

end # module Sketchup::Su2osm
