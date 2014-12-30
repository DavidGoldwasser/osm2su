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

  def self.store_current_material_to_space_attributes(group)

    # get material
    current_material = group.material

    if not current_material.nil?
      # check for attributes
      resource_type = current_material.get_attribute 'su2osm', 'resource_type'
      if resource_type == "space_type"
        uuid = current_material.get_attribute 'su2osm', 'space_type_uuid'
        group.set_attribute 'su2osm', 'space_type_name', current_material.name # todo - relies on material name being space type name. That will probably change (typical)
        group.set_attribute 'su2osm', 'space_type_uuid', uuid
      elsif resource_type == "thermal_zone"
        uuid = current_material.get_attribute 'su2osm', 'thermal_zone_uuid'
        group.set_attribute 'su2osm', 'thermal_zone_name', current_material.name
        group.set_attribute 'su2osm', 'thermal_zone_uuid', uuid
      elsif resource_type == "building_story"
        uuid = current_material.get_attribute 'su2osm', 'building_story_uuid'
        group.set_attribute 'su2osm', 'building_story_name', current_material.name
        group.set_attribute 'su2osm', 'building_story_uuid', uuid
      else
        # make new materials if in editable render mode
        if @render_mode == "space_type_name"
          current_material.set_attribute 'su2osm', 'space_type_uuid', '' # there isn't a handle yet since this doesn't exist in the OSM file
          current_material.set_attribute 'su2osm', 'space_type_entity_id', current_material.entityID
          current_material.set_attribute 'su2osm', 'resource_type', "space_type"
          group.set_attribute 'su2osm', 'space_type_name', current_material.name
          group.set_attribute 'su2osm', 'space_type_uuid', ""
        elsif @render_mode == "thermal_zone_name"
          current_material.set_attribute 'su2osm', 'thermal_zone_uuid', '' # there isn't a handle yet since this doesn't exist in the OSM file
          current_material.set_attribute 'su2osm', 'thermal_zone_entity_id', current_material.entityID
          current_material.set_attribute 'su2osm', 'resource_type', "thermal_zone"
          group.set_attribute 'su2osm', 'thermal_zone_name', current_material.name
          group.set_attribute 'su2osm', 'thermal_zone_uuid', ""
        elsif @render_mode == "building_story_name"
          current_material.set_attribute 'su2osm', 'building_story_uuid', '' # there isn't a handle yet since this doesn't exist in the OSM file
          current_material.set_attribute 'su2osm', 'building_story_entity_id', current_material.entityID
          current_material.set_attribute 'su2osm', 'resource_type', "building_story"
          group.set_attribute 'su2osm', 'building_story_name', current_material.name
          group.set_attribute 'su2osm', 'building_story_uuid', ""
        else
          # do nothing with this material. We are not in a render mode that supports painting attributes
        end
      end
    end

  end

  def self.space_attribute_render_mode(string)

    model = Sketchup.active_model
    status = model.start_operation('Change Render Mode', true)

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      next if entity.layer.name != "su2osm - Space"

      # store existing material attribute in space group before change
      store_current_material_to_space_attributes(entity)

      # change material
      attribute = entity.get_attribute 'su2osm', string
      if attribute.to_s == ""
        entity.material = nil
      else
        entity.material = material_hash[attribute]
      end

    end

    # todo - later I'll need to drill down to surfaces and other groups. I'll also have to do this when I switch between surface vs. space render modes.

    @render_mode = string
    status = Sketchup.active_model.commit_operation

  end

  def self.clear_render_mode

    space_attribute_render_mode("")
    status = Sketchup.active_model.commit_operation

  end

  def self.render_by_space_type

    space_attribute_render_mode("space_type_name")
    status = Sketchup.active_model.commit_operation

  end

  def self.render_by_thermal_zone

    space_attribute_render_mode("thermal_zone_name")
    status = Sketchup.active_model.commit_operation

  end

  def self.render_by_building_story

    space_attribute_render_mode("building_story_name")
    status = Sketchup.active_model.commit_operation

  end

  def self.render_by_air_loop

    model = Sketchup.active_model
    status = model.start_operation('Render By Air Loop', true)

    # air loop hash
    air_loop_hash = {}

    @background_osm_model.getAirLoopHVACs.each do |air_loop|
      thermal_zones = []
      # see if material already exists by this name
      if  material_hash[air_loop.name.to_s]
        material = material_hash[air_loop.name.to_s]
      else
        material = Sketchup.active_model.materials.add(air_loop.name.to_s)
        color = Sketchup::Color.new(rand(264), rand(264), rand(264), 1.0)
        material.color = color
      end
      air_loop.demandComponents.each do |component|
        if component.to_ThermalZone.is_initialized
          thermal_zone = component.to_ThermalZone.get
          thermal_zones << thermal_zone.name.get
        end
      end
      air_loop_hash[material] = thermal_zones
    end

    Sketchup.active_model.active_entities.each do |entity|
      next if entity.class.to_s != "Sketchup::Group" and entity.class.to_s != "Sketchup::ComponentInstance"
      surface_group_type = entity.get_attribute 'su2osm', 'surface_group_type'
      next if surface_group_type.to_s != "space" # todo - should probably check layer instead of this
      thermal_zone_name = entity.get_attribute 'su2osm', 'thermal_zone_name'

      # store existing material attribute in space group before change
      store_current_material_to_space_attributes(entity)

      # find airloop and assign material
      found_match = false
      air_loop_hash.each do |k,v|
        if v.include?(thermal_zone_name.to_s)
          entity.material = k
          found_match = true
          next
        end
      end

      # make white if didn't find a match
      if not found_match then entity.material = nil end

    end

    @render_mode = "air_loops"
    status = model.commit_operation

  end

  def self.render_by_lpd

    puts ""
    puts ">>Rendering By Lighting Power Density"

  end

end # module Sketchup::Su2osm
