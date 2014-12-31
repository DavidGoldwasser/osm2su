# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'

module Sketchup::Su2osm

  def self.import_osm_file_as_sketchup_groups

    # load openstudio
    begin
      require Sketchup.read_default("su2osm","openstudio_path").to_s
    rescue LoadError
      UI.messagebox('Could not load OpenStudio, please set valid path to openstudio.rb before importing or merging to OSM files.')
      return
    end

    # dialog for user to browse to osm file to open
    open_path = UI.openpanel("Import OSM file as SketchUp Groups", "", "*.osm")

    puts ""
    puts ">>import start" # todo - would nice to have dialog stay open and then maybe one providing stats after it is done

    puts ""
    puts "File - " + open_path

    # this is useful when opening multiple models to set attributes not yet triggered by render mode change or save
    clear_render_mode

    # Open OSM file
    background_osm_model = OpenStudio::Model::Model::load(OpenStudio::Path.new(open_path)).get
    @background_osm_model = background_osm_model

    # number of spaces
    spaces = background_osm_model.getSpaces
    #puts "Model has " + spaces.size.to_s + " spaces"

    # number of base surfaces
    base_surfaces = background_osm_model.getSurfaces
    #puts "Model has " + base_surfaces.size.to_s + " base surfaces"

    # number of base surfaces
    sub_surfaces = background_osm_model.getSubSurfaces
    #puts "Model has " + sub_surfaces.size.to_s + " sub surfaces"

    # number of surfaces
    shading_surfaces = background_osm_model.getShadingSurfaces
    #puts "Model has " + shading_surfaces.size.to_s + " shading surfaces"

    # number of surfaces
    partition_surfaces = background_osm_model.getInteriorPartitionSurfaces
    #puts "Model has " + partition_surfaces.size.to_s + " interior partition surfaces"

    # get SketchUp model and entities
    skp_model = Sketchup.active_model
    entities = skp_model.active_entities

    # create layers matched to OpenStudio surface group types
    layers = skp_model.layers
    new_layer = layers.add("su2osm - SiteShadingGroup")
    new_layer = layers.add("su2osm - BuildingAndSpaceShadingGroup")
    new_layer = layers.add("su2osm - Space")
    new_layer = layers.add("su2osm - InteriorPartitionSurfaceGroup")

    # set render mode to color by layers (interior partition and shading can match OpenStudio, spaces should be something unique)?

    # use building rotation to set north direction in SketchUp
    building = background_osm_model.getBuilding
    rotation = building.northAxis # not sure of units
    info = skp_model.shadow_info
    info["NorthAngle"] = rotation*-1.0
    if rotation != 0.0
      info["DisplayNorth"] = rotation*-1.0
    end

    # create def to make group
    def self.make_group(parent,name,layer,xOrigin,yOrigin,zOrigin,rotation)
      group = parent.entities.add_group
      #set name and layer
      group.name=name
      group.layer=layer
      # set group origin, rotation
      point = Geom::Point3d.new "#{xOrigin}m".to_l,"#{yOrigin}m".to_l,"#{zOrigin}m".to_l
      t = Geom::Transformation.new point
      group.move! t
      # rotate
      tr = Geom::Transformation.rotation ["#{xOrigin}m".to_l,"#{yOrigin}m".to_l,"#{zOrigin}m".to_l], [0, 0, 1], rotation.degrees
      group.transform! tr

      return group

    end

    # create  def to make a surface
    def self.make_surface(group, vertices)
      entities = group.entities
      pts = []
      verticesTestString = []
      toleranceValue = 10000
      vertices.each do |pt|
        if verticesTestString.include? "#{(pt.x*toleranceValue).to_i},#{(pt.y*toleranceValue).to_i},#{(pt.z*toleranceValue).to_i}" # added test to resolve duplicate vertices, probably need to address tolerance.
          puts "removing point within tolerance of another point in face in #{group.name}."
          next # this was added to avoid ruby error on add_face pts if pts were too similar to each other SketchUp failed showing duplicate
        end
        verticesTestString << "#{(pt.x*toleranceValue).to_i},#{(pt.y*toleranceValue).to_i},#{(pt.z*toleranceValue).to_i}"
        pts << ["#{pt.x}m".to_l,"#{pt.y}m".to_l,"#{pt.z}m".to_l]
      end
      if pts.size < 3
        puts "skipping face in #{group.name} because it has less than three vertices."
      else
        face = entities.add_face pts
      end
    end

    # get SketchUp materials, and store in hash to check as new materials are made
    materials = Sketchup.active_model.materials
    materials_hash = {}
    materials.each { |material|
      materials_hash[material.name] = material
    }

    # loop through space types to create materials
    background_osm_model.getSpaceTypes.each do |space_type|
      if materials_hash[space_type.name.to_s].nil?
        material = materials.add(space_type.name.to_s)
      else
        material = materials_hash[space_type.name.to_s]
      end
      if space_type.renderingColor.is_initialized
        rendering_color = space_type.renderingColor.get
        color = Sketchup::Color.new(rendering_color.renderingRedValue, rendering_color.renderingGreenValue, rendering_color.renderingBlueValue, 255) # set alpha at material, not color
      else
        color = Sketchup::Color.new(rand(255), rand(255), rand(255), 1.0)
      end
      material.color = color
      material.alpha = rendering_color.renderingAlphaValue/255.0 # fraction is used in Sketchup
      material.set_attribute 'su2osm', 'space_type_uuid', space_type.handle
      material.set_attribute 'su2osm', 'space_type_entity_id', material.entityID
      material.set_attribute 'su2osm', 'resource_type', "space_type"
    end

    # loop through thermal zones to make materials
    background_osm_model.getThermalZones.each do |thermal_zone|
      if materials_hash[thermal_zone.name.to_s].nil?
        material = materials.add(thermal_zone.name.to_s)
      else
        material = materials_hash[thermal_zone.name.to_s]
      end
      if thermal_zone.renderingColor.is_initialized
        rendering_color = thermal_zone.renderingColor.get
        color = Sketchup::Color.new(rendering_color.renderingRedValue, rendering_color.renderingGreenValue, rendering_color.renderingBlueValue, 255) # set alpha at material, not color
      else
        color = Sketchup::Color.new(rand(255), rand(255), rand(255), 1.0)
      end
      material.color = color
      material.alpha = rendering_color.renderingAlphaValue/255.0 # fraction is used in Sketchup
      material.set_attribute 'su2osm', 'thermal_zone_uuid', thermal_zone.handle
      material.set_attribute 'su2osm', 'thermal_zone_entity_id', material.entityID
      material.set_attribute 'su2osm', 'resource_type', "thermal_zone"
    end

    # loop through building stories to make materials
    background_osm_model.getBuildingStorys.each do |story|
      if materials_hash[story.name.to_s].nil?
        material = materials.add(story.name.to_s)
      else
        material = materials_hash[story.name.to_s]
      end
      if story.renderingColor.is_initialized
        rendering_color = story.renderingColor.get
        color = Sketchup::Color.new(rendering_color.renderingRedValue, rendering_color.renderingGreenValue, rendering_color.renderingBlueValue, 255) # set alpha at material, not color
      else
        color = Sketchup::Color.new(rand(255), rand(255), rand(255), 1.0)
      end
      material.color = color
      material.alpha = rendering_color.renderingAlphaValue/255.0 # fraction is used in Sketchup
      material.set_attribute 'su2osm', 'building_story_uuid', story.handle
      material.set_attribute 'su2osm', 'building_story_entity_id', material.entityID
      material.set_attribute 'su2osm', 'resource_type', "building_story"
    end

    # loop through spaces
    spaces.each do |space|
      # create space
      group = make_group(Sketchup.active_model,space.name.get,"su2osm - Space",space.xOrigin,space.yOrigin,space.zOrigin,space.directionofRelativeNorth*-1)
      group.set_attribute 'su2osm', 'space_uuid', space.handle
      group.set_attribute 'su2osm', 'entity_id', group.entityID # idea was to identify clone from original, but will need to re-populate this every time the SketchUp file is loaded (if the user saves that format)
      group.set_attribute 'su2osm', 'surface_group_type', "space"

      # populate space attributes
      if space.spaceType.is_initialized and !space.isSpaceTypeDefaulted # don't add attributes if space type is defaulted
        space_type = space.spaceType.get
        group.set_attribute 'su2osm', 'space_type_name', space_type.name.to_s
        group.set_attribute 'su2osm', 'space_type_uuid', space_type.handle
        #puts group.get_attribute 'su2osm', 'space_type_name'
      end
      if space.thermalZone.is_initialized
        thermal_zone = space.thermalZone.get
        group.set_attribute 'su2osm', 'thermal_zone_name', thermal_zone.name.to_s
        group.set_attribute 'su2osm', 'thermal_zone_uuid', thermal_zone.handle
      end
      if space.buildingStory.is_initialized
        building_story = space.buildingStory.get
        group.set_attribute 'su2osm', 'building_story_name', building_story.name.to_s
        group.set_attribute 'su2osm', 'building_story_uuid', building_story.handle
      end

      # loop through base surfaces
      base_surfaces = space.surfaces
      base_surfaces.each do |base_surface|
        # create base surface
        # puts "surface name: #{base_surface.name}"
        make_surface(group, base_surface.vertices)

        # loop through sub surfaces
        sub_surfaces = base_surface.subSurfaces
        sub_surfaces.each do |sub_surface|
          # create sub surface
          # puts "sub surface name: #{sub_surface.name}"
          make_surface(group, sub_surface.vertices)

        end # end of sub_surfaces.each do

      end # end of base_surfaces.each do

      # loop through space shading groups
      space_shading_groups = space.shadingSurfaceGroups
      space_shading_groups.each do |space_shading_group|
        # create group
        # puts "space shading group name: #{space_shading_group.name}"
        sub_group = make_group(group,space_shading_group.name.get,"su2osm - BuildingAndSpaceShadingGroup",space_shading_group.xOrigin,space_shading_group.yOrigin,space_shading_group.zOrigin,space_shading_group.directionofRelativeNorth*-1)

        #loop through shading surfaces
        shading_surfaces = space_shading_group.shadingSurfaces
        shading_surfaces.each do |shading_surface|
          # create shading surfaces
          # puts "space shading surface name: #{shading_surface.name}"
          make_surface(sub_group, shading_surface.vertices)

        end # end of shading_surfaces.each do

      end  # end of space_shading_groups.each do

      # loop through interior partition groups
      interior_partition_groups = space.interiorPartitionSurfaceGroups
      interior_partition_groups.each do |interior_partition_group|
        # create group
        # puts "interior partition group name: #{interior_partition_group.name}"
        sub_group = make_group(group,interior_partition_group.name.get,"su2osm - InteriorPartitionSurfaceGroup",interior_partition_group.xOrigin,interior_partition_group.yOrigin,interior_partition_group.zOrigin,interior_partition_group.directionofRelativeNorth*-1)

        #loop through interior partition surfaces
        interior_partition_surfaces = interior_partition_group.interiorPartitionSurfaces
        interior_partition_surfaces.each do |interior_partition_surface|
          # create interior partition surfaces
          # puts "interior partition surface name: #{interior_partition_surface.name}"
          make_surface(sub_group, interior_partition_surface.vertices)

        end # end of interior_partition_surfaces.each do

      end  # end of interior_partition_groups.each do

    end # end of spaces.each do

    #loop through shading surface groups, skip if space shading, those are imported with spaces
    shading_surface_groups = background_osm_model.getShadingSurfaceGroups
    shading_surface_groups.each do |shading_surface_group|
      # create group
      if not shading_surface_group.shadingSurfaceType == "Space"
        if shading_surface_group.shadingSurfaceType == "Building"
          group = make_group(Sketchup.active_model,shading_surface_group.name.get,"su2osm - BuildingAndSpaceShadingGroup",shading_surface_group.xOrigin,shading_surface_group.yOrigin,shading_surface_group.zOrigin,shading_surface_group.directionofRelativeNorth*-1)
        else
          group = make_group(Sketchup.active_model,shading_surface_group.name.get,"su2osm - SiteShadingGroup",shading_surface_group.xOrigin,shading_surface_group.yOrigin,shading_surface_group.zOrigin,shading_surface_group.directionofRelativeNorth*-1)
        end

        #loop through shading surfaces
        shading_surfaces = shading_surface_group.shadingSurfaces
        shading_surfaces.each do |shading_surface|
          # create shading surfaces
          # puts "shading surface name: #{shading_surface.name}"
          make_surface(group, shading_surface.vertices)

        end # end of shading_surfaces.each do

      end # end of if not shading_surface_group.type == "Space"

    end #end of shading_surface_groups.each do

    #todo - see why spaces are not passing manifold solid test. Seems like old SketchUp issue where if I exploded and re-make it then shows as solid. Maybe even just re-open it.

    #zoom extents
    view = Sketchup.active_model.active_view
    new_view = view.zoom_extents

    # set default rendermode
    render_by_space_type

  end

end # module Sketchup::Su2osm