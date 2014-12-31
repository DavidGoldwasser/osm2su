# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'

module Sketchup::Su2osm

  def self.merge_sketchup_groups_to_osm_file

    # load openstudio
    begin
      require Sketchup.read_default("su2osm","openstudio_path").to_s
    rescue LoadError
      UI.messagebox('Could not load OpenStudio, please set valid path to openstudio.rb before importing or merging to OSM files.')
      return
    end

    # brose for file
    merge_path = 'C:\Users\dgoldwas\Documents\aaaWorking\test2.osm' #runner.getStringArgumentValue("merge_path",user_arguments)

    # dialog for user to browse to osm file to open
    merge_path = UI.savepanel("Merge SketchUp Groups to OSM file", "", "*.osm")

    # gather user input
    prompts = ["Scope of Merge","Merge Geometry","Merge Space Attributes"]
    defaults = ["All Groups",true,true]
    list = ["Selected Groups|All Groups","true","true"] # don't enable false as option until I update code to support it.
    input = UI.inputbox(prompts, defaults, list, "Merge SketchUp Groups to OSM file")
    merge_scope = input[0]
    merge_geometry = input[1]
    merge_space_attributes = input[2]

    if input[0] == "All Groups"
      merge_selected_only = false
    else
      merge_selected_only = true
    end

    # Open OSM file
    if not OpenStudio::Model::Model::load(OpenStudio::Path.new(merge_path)).empty?
      @background_osm_model = OpenStudio::Model::Model::load(OpenStudio::Path.new(merge_path)).get
    else
      @background_osm_model = OpenStudio::Model::Model.new # make new model if path given wasn't an existing model
    end

    # get surface groups from osm
    @spaces = @background_osm_model.getSpaces
    @shading_groups = @background_osm_model.getShadingSurfaceGroups
    @interior_partition_groups = @background_osm_model.getInteriorPartitionSurfaceGroups

    puts ""
    puts ">>merge start"  # todo - would be nice ot have dialog for this

    puts ""

    # get SketchUp model and entities
    skp_model = Sketchup.active_model
    if not merge_selected_only
      entities = skp_model.active_entities
    else
      entities = skp_model.selection
    end

    #use north direction in SketchUp to set building rotation
    info = skp_model.shadow_info
    building = @background_osm_model.getBuilding
    building.setNorthAxis(info["NorthAngle"]*-1.0)

    #get spaces shading groups and interior partition groups

    #create def to make space
    def self.make_space(name,xOrigin,yOrigin,zOrigin,rotation,space_type,thermal_zone,building_story)

      #flag to create new space
      need_space = true

      #loop through spaces in model
      @spaces.each do |space|

        if space.name.to_s == name

          #delete existing OSM surfaces
          #puts "removing surfaces from existing space named #{space.name}."
          surfaces = space.surfaces
          surfaces.each do |surface|
            surface.remove
          end

          need_space = false
          space.setXOrigin(xOrigin.to_f)
          space.setYOrigin(yOrigin.to_f)
          space.setZOrigin(zOrigin.to_f)
          space.setDirectionofRelativeNorth(rotation)

          # set space attributes
          if !space_type.nil? then space.setSpaceType(space_type) end
          if !thermal_zone.nil? then space.setThermalZone(thermal_zone) end
          if !building_story.nil? then space.setBuildingStory(building_story) end

          @result = space
          @current_spaces << space

        end #end of if space.name = name

      end #end of spaces.each do

      #make space and set name
      if need_space

        #add a space to the model without any geometry or loads, want to make sure measure works or fails gracefully
        #puts "making new space named #{name}"
        space = OpenStudio::Model::Space.new(@background_osm_model)
        space.setName(name)
        space.setXOrigin(xOrigin.to_f)
        space.setYOrigin(yOrigin.to_f)
        space.setZOrigin(zOrigin.to_f)
        space.setDirectionofRelativeNorth(rotation)

        # set space attributes
        if !space_type.nil? then space.setSpaceType(space_type) end
        if !thermal_zone.nil? then space.setThermalZone(thermal_zone) end
        if !building_story.nil? then space.setBuildingStory(building_story) end

        @result = space
      end

      return @result
    end #end of def make_space

    # create def to make space surface
    def self.make_space_surfaces(space,group)

      #hash for base surface types
      base_surface_array = []

      #hash for sub surface types
      window_hash = Hash.new #key is current face, value is parent surface
      skylight_hash = Hash.new
      door_hash = Hash.new

      # different method to get entities for group vs. component
      if group.class.to_s == "Sketchup::Group"
        entities = group.entities
      else group.class.to_s == "Sketchup::ComponentInstance"
        entities = group.definition.entities
      end

      #categorize surfaces
      entities.each do |entity|
        if entity.class.to_s == "Sketchup::Face"

          #array to help find identify sub-surfaces
          edge_faces = []

          edges = entity.edges
          edges.each do |edge|
            adjacent_faces = edge.faces
            adjacent_faces.each do |adjacent_face|
              if not adjacent_face == entity #this is needed to exclude the current face
                edge_faces << adjacent_face
              end
            end
          end #end of edges.each do

          if edge_faces.uniq.size >= 3 # todo - update logic, this will catch doors with split floor under them
            #this is a base surface
            base_surface_array << entity #later make hash that includes value of an array of sub surfaces?
          elsif edge_faces.uniq.size == 1 and edge_faces.size == edges.size #this second test checks for edge that doesn't match to any faces
            #this is a window
            window_hash[entity] = edge_faces[0] #the value here is the parent
          else #this could be a door or base surface. Need further testing

            #test to see if all but one edges have the same adjacent face
            number_of_matches = 0
            number_of_matches_alt = 0
            edge_faces.each do |edge_face|
              if edge_faces[0] == edge_face
                number_of_matches += 1
              end
              if edge_faces[1] == edge_face
                number_of_matches_alt += 1
              end
            end #end of edge_faces.each do

            if number_of_matches_alt == edges.size - 1
              #this is a door
              door_hash[entity] = edge_faces[1] #any face but the first one is the parent
            elsif number_of_matches == edges.size - 1
              #this is a door
              door_hash[entity] = edge_faces[0] #the first face is the parent
            else
              #this is a base surface
              base_surface_array << entity
            end

          end #end of edge_faces.uniq.size

          #todo - should test that sub-surfaces don't have inner loop. If it does warn and ignore?

          #todo - add in check for three faces sharing an edge. Generally should just be two

        end #end of if entity.class.to_s == "Sketchup::Face"
      end #end of entities.each.do

      #create base surfaces
      base_surface_array.each do |entity|

          # get outer loop to remove windows (unless fixed above where doors are fixed)
          loop = entity.outer_loop

          # get vertices for OpenStudio base surface
          vertices = loop.vertices

          # array of edges that have to be re-drawn after erase to address issue of door in base surface
          erasedEdges = []

          # make an OpenStudio vector of of Point3d objects
          newVertices = []

          vertices.each do |vertex|
            x = vertex.position[0].to_m
            y = vertex.position[1].to_m
            z = vertex.position[2].to_m
            newVertices << OpenStudio::Point3d.new(x,y,z)
          end  #end of vertices.each do

          #make new surface and assign space
          new_surface = OpenStudio::Model::Surface.new(newVertices,@background_osm_model)
          new_surface.setSpace(space)

          #use hash to identify windows of this new base surface
          window_hash.each do |k,v|
            if v == entity

              # get vertices for OpenStudio sub surface
              loop = k.outer_loop
              vertices = loop.vertices

              # make an OpenStudio vector of of Point3d objects
              newVertices = []

              vertices.each do |vertex|
                x = vertex.position[0].to_m
                y = vertex.position[1].to_m
                z = vertex.position[2].to_m
                newVertices << OpenStudio::Point3d.new(x,y,z)
              end  #end of vertices.each do

              #make new surface and assign space
              new_sub_surface = OpenStudio::Model::SubSurface.new(newVertices,@background_osm_model)
              new_sub_surface.setSurface(new_surface)

            end
          end #end of window_hash.each do

          remake_base_surface = false
          possible_source_surfaces = [entity]

          #use hash to identify doors of this new base surface
          door_hash.each do |k,v|
            if v == entity

              # temp array to fix base surface
              possible_source_surfaces << k

              # get vertices for OpenStudio sub surface
              loop = k.outer_loop
              vertices = loop.vertices

              # make an OpenStudio vector of of Point3d objects
              newVertices = []

              vertices.each do |vertex|
                x = vertex.position[0].to_m
                y = vertex.position[1].to_m
                z = vertex.position[2].to_m
                newVertices << OpenStudio::Point3d.new(x,y,z)
              end  #end of vertices.each do

              #make new surface and assign space
              new_sub_surface = OpenStudio::Model::SubSurface.new(newVertices,@background_osm_model)
              new_sub_surface.setSurface(new_surface)

              # store all sub surface edges
              doorEdges = []
              doorPoints = []
              edges = loop.edges
              edges.each do |edge|
                doorEdges << [edge.vertices[0].position,edge.vertices[1].position,k,v] #k is entity (door), v is parent (base surface), need this in case surface swapped
                doorPoints << edge.vertices[0].position
              end

              # erase door surface
              #k.erase!

              # redraw erased edges to preserve door in current SketchUp model
              doorEdges.each do |edgePoints|
                pointA = edgePoints[0]
                pointB = edgePoints[1]
                line = entity.parent.entities.add_line pointA,pointB
              end

            end
          end #end of door_hash.each do

          #re-make base surfaces with doors
          if remake_base_surface

            # get outer loop to remove windows (unless fixed above where doors are fixed)
            possible_source_surfaces.each do |updated_face|
              if not updated_face.deleted?
                loop = updated_face.outer_loop
                next #once I find a face I should be done.
              end
            end

            # get vertices for OpenStudio base surface
            vertices = loop.vertices

            # make an OpenStudio vector of of Point3d objects
            newVertices = []

            vertices.each do |vertex|
              x = vertex.position[0].to_m
              y = vertex.position[1].to_m
              z = vertex.position[2].to_m
              newVertices << OpenStudio::Point3d.new(x,y,z)
            end  #end of vertices.each do

            #make updated surface
            new_surface.setVertices(newVertices)

          end  #end of if remake_base_surface

      end #end of base_surfaces_array.each.do

    end #end of make_space_surfaces(space,group)

    #create def to make shading surface group
    def self.make_shading_surface_group(name,xOrigin,yOrigin,zOrigin,rotation,shadingSurfaceType,parent)

      #flag to create new group
      need_group = true

      #loop through groups in model
      @shading_groups.each do |shading_surface_group|

        if shading_surface_group.name.to_s == name

          #delete existing OSM surfaces
          #puts "removing surfaces from existing shading surface group named #{shading_surface_group.name}."
          surfaces = shading_surface_group.shadingSurfaces
          surfaces.each do |surface|
            surface.remove
          end

          need_group = false
          shading_surface_group.setXOrigin(xOrigin.to_f)
          shading_surface_group.setYOrigin(yOrigin.to_f)
          shading_surface_group.setZOrigin(zOrigin.to_f)
          shading_surface_group.setDirectionofRelativeNorth(rotation)
          @result = shading_surface_group
          @current_shading_surface_groups << shading_surface_group

        end #end of if space.name = name

      end #end of spaces.each do

      #make group and set name
      if need_group

        #add a space to the model without any geometry or loads, want to make sure measure works or fails gracefully
        #puts "making new shading surface group named #{name}"
        shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(@background_osm_model)  #this can be at top level or in space
        shading_surface_group.setName(name)
        shading_surface_group.setShadingSurfaceType(shadingSurfaceType)
        if not parent.to_s == ""
          shading_surface_group.setSpace(parent)
        end
        shading_surface_group.setXOrigin(xOrigin.to_f)
        shading_surface_group.setYOrigin(yOrigin.to_f)
        shading_surface_group.setZOrigin(zOrigin.to_f)
        shading_surface_group.setDirectionofRelativeNorth(rotation)
        @result = shading_surface_group
      end

      return @result
    end #end of make_shading_surface_group(name,xOrigin,yOrigin,zOrigin,rotation,parent)

    # create def to make shading surface
    def self.make_shading_surfaces(shading_surface_group, group)

      # different method to get entities for group vs. component
      if group.class.to_s == "Sketchup::Group"
        entities = group.entities
      else group.class.to_s == "Sketchup::ComponentInstance"
        entities = group.definition.entities
      end

      #loop through surfaces to make OS surfaces
      entities.each do |entity|
        if entity.class.to_s == "Sketchup::Face"
          vertices = entity.vertices

          # make an OpenStudio vector of of Point3d objects
          newVertices = []

          vertices.each do |vertex|
            x = vertex.position[0].to_m
            y = vertex.position[1].to_m
            z = vertex.position[2].to_m
            newVertices << OpenStudio::Point3d.new(x,y,z)
          end
          new_surface = OpenStudio::Model::ShadingSurface.new(newVertices,@background_osm_model)
          new_surface.setShadingSurfaceGroup(shading_surface_group)

        end
      end #end of entities.each.do

    end #end of make_shading_surfaces

    # create def to make interior partition group
    def self.make_interior_partition_group(name,xOrigin,yOrigin,zOrigin,rotation,parent)

      #flag to create new group
      need_group = true

      #loop through spaces in model
      @interior_partition_groups.each do |interior_partition_group|

        if interior_partition_group.name.to_s == name

          #delete existing OSM surfaces
          #puts "removing surfaces from existing interior partition group named #{interior_partition_group.name}."
          surfaces = interior_partition_group.interiorPartitionSurfaces
          surfaces.each do |surface|
            surface.remove
          end

          need_group = false
          interior_partition_group.setXOrigin(xOrigin.to_f)
          interior_partition_group.setYOrigin(yOrigin.to_f)
          interior_partition_group.setZOrigin(zOrigin.to_f)
          interior_partition_group.setDirectionofRelativeNorth(rotation)
          @result = interior_partition_group
          @current_interior_partition_groups << interior_partition_group

        end #end of if space.name = name

      end #end of spaces.each do

      #make group and set name
      if need_group

        #add a space to the model without any geometry or loads, want to make sure measure works or fails gracefully
        #puts "making new interior partition surface group named #{name}"
        interior_partition_group = OpenStudio::Model::InteriorPartitionSurfaceGroup.new(@background_osm_model)  #this needs to be the space it is in
        interior_partition_group.setName(name)
        interior_partition_group.setSpace(parent)
        interior_partition_group.setXOrigin(xOrigin.to_f)
        interior_partition_group.setYOrigin(yOrigin.to_f)
        interior_partition_group.setZOrigin(zOrigin.to_f)
        interior_partition_group.setDirectionofRelativeNorth(rotation)
        @result = interior_partition_group
      end

      return @result
    end #end of make_interior_partition_group

    # create def to make interior partition surface
    def self.make_interior_partition_surfaces(interior_partition_group, group)

      # different method to get entities for group vs. component
      if group.class.to_s == "Sketchup::Group"
        entities = group.entities
      else group.class.to_s == "Sketchup::ComponentInstance"
        entities = group.definition.entities
      end

      #loop through surfaces to make OS surfaces
      entities.each do |entity|
        if entity.class.to_s == "Sketchup::Face"
          vertices = entity.vertices

          # make an OpenStudio vector of of Point3d objects
          newVertices = []

          vertices.each do |vertex|
            x = vertex.position[0].to_m
            y = vertex.position[1].to_m
            z = vertex.position[2].to_m
            newVertices << OpenStudio::Point3d.new(x,y,z)
          end
          new_surface = OpenStudio::Model::InteriorPartitionSurface.new(newVertices,@background_osm_model)
          new_surface.setInteriorPartitionSurfaceGroup(interior_partition_group)

        end
      end #end of entities.each.do

    end #end of make_interior_partition_surfaces

    #array of space, shading groups, and interior partition groups. Later will delete objects in OSM that don't exist in SKP
    @current_spaces = []
    @current_shading_surface_groups = []
    @current_interior_partition_groups = []

    #making array of groups and components
    groups = []
    entities.each do |entity|
      if entity.class.to_s == "Sketchup::Group" or entity.class.to_s == "Sketchup::ComponentInstance"
        entity.make_unique #this is only needed if a group was copied.
        groups << entity
      end
    end #end of entities.each.do

    # make hashes of space types, thermal zones, and building stories
    space_type_hash = {}
    @background_osm_model.getSpaceTypes.each do |space_type|
      space_type_hash[space_type.name.to_s] = space_type
    end
    thermal_zone_hash = {}
    @background_osm_model.getThermalZones.each do |thermal_zone|
      thermal_zone_hash[thermal_zone.name.to_s] = thermal_zone
    end
    building_story_hash = {}
    @background_osm_model.getBuildingStorys.each do |building_story|
      building_story_hash[building_story.name.to_s] = building_story
    end

    # add new resources and edit display color for existing ones
    Sketchup.active_model.materials.each do |material|
      resource_type = material.get_attribute 'su2osm', 'resource_type'
      r = material.color.red
      g = material.color.green
      b = material.color.blue
      alpha = material.alpha # get from material, and not color
      if resource_type == "space_type"
        if space_type_hash[material.name.to_s].nil?
          # make new resource and add to hash
          resource = OpenStudio::Model::SpaceType.new(@background_osm_model)
          resource.setName(material.name)
          rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          resource.setRenderingColor(rendering_color)
          space_type_hash[resource.name.to_s] = resource
        else
          # update color on existing resource
          resource = space_type_hash[material.name.to_s]
          rendering_color = resource.renderingColor
          if rendering_color.is_initialized
            rendering_color = rendering_color.get
          else
            rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          end
        end

      elsif resource_type == "thermal_zone"
        if thermal_zone_hash[material.name.to_s].nil?
          # make new resource and add to hash
          resource = OpenStudio::Model::ThermalZone.new(@background_osm_model)
          resource.setName(material.name)
          rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          resource.setRenderingColor(rendering_color)
          thermal_zone_hash[resource.name.to_s] = resource
        else
          # update color on existing resource
          resource = thermal_zone_hash[material.name.to_s]
          rendering_color = resource.renderingColor
          if rendering_color.is_initialized
            rendering_color = rendering_color.get
          else
            rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          end
        end

      elsif resource_type == "building_story"
        if building_story_hash[material.name.to_s].nil?
          # make new resource and add to hash
          resource = OpenStudio::Model::BuildingStory.new(@background_osm_model)
          resource.setName(material.name)
          rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          resource.setRenderingColor(rendering_color)
          building_story_hash[resource.name.to_s] = resource
        else
          # update color on existing resource
          resource = building_story_hash[material.name.to_s]
          rendering_color = resource.renderingColor
          if rendering_color.is_initialized
            rendering_color = rendering_color.get
          else
            rendering_color = OpenStudio::Model::RenderingColor.new(@background_osm_model)
          end
        end

      else
        # no attributes on material or unexpected resource type
        next
      end

      # set rendering color
      rendering_color.setRenderingRedValue(r)
      rendering_color.setRenderingGreenValue(g)
      rendering_color.setRenderingBlueValue(b)
      integer_alpha = alpha*255.0.round
      rendering_color.setRenderingAlphaValue(integer_alpha.to_i) # convert from fraction to 0-255 value

    end


    # make array of groups in model. Rename duplicate names on the fly
    groupNames = []

    #loop through groups in SketchUp model
    groups.each do |group|

      # if group name is blank create a new one
      if group.name == "" then group.name = "Group" end

      # make group name unique if it isn't
      if groupNames.include? group.name
        counter = 1
        uniqueNameFound = false

        # loop through this until unique name found
        until uniqueNameFound

          # create target name
          if group.name.include? " - copy "
            # this is to keep clean naming if you may a copy of a space that was copied in an earlier session
            indexPosition = group.name.rindex(" - copy ")
            targetName = "#{group.name[0..indexPosition]}- copy #{counter}"
          else
            targetName = "#{group.name} - copy #{counter}"
          end

          # test and assign name or change counter
          if groupNames.include? targetName
            counter += 1
          else
            group.name = targetName
            uniqueNameFound = true
          end
        end
      end

      # push final name to array
      groupNames << group.name

      # get transformation
      t = group.transformation

      # address scaling and not z axis rotation
      explodeNeededFlag = false
      if not (t.xscale.to_s == "1.0" and t.yscale.to_s == "1.0" and t.zscale.to_s == "1.0" and t.zaxis.to_s == "(0.0, 0.0, 1.0)")  then explodeNeededFlag = true end

      # this was added to catch flipped group or group with scale of -1 that isn't caught by test above
      t.extend(TransformationHelper)
      if t.flipped_x? then explodeNeededFlag = true end
      if t.flipped_y? then explodeNeededFlag = true end
      if t.flipped_z? then explodeNeededFlag = true end

      if explodeNeededFlag == true
        puts "exploding group, attributes will be lost."

        # gather group inputs
        oldGroup = group
        parent = group.parent
        name = group.name
        layer = group.layer
        material = group.material

        # space attributes that might need
        space_type = group.get_attribute 'su2osm', 'space_type_name'
        thermal_zone = group.get_attribute 'su2osm', 'thermal_zone_name'
        building_story = group.get_attribute 'su2osm', 'building_story_name'
        surface_group_type = group.get_attribute 'su2osm', 'surface_group_type'

        # make new group and set transformation
        group.material=nil # clear out material before surfaces move to copy
        group = parent.entities.add_group(oldGroup)
        # create group set group origin, rotation
        point = Geom::Point3d.new t.origin.x,t.origin.y,t.origin.z
        rotation = t.rotz
        t = Geom::Transformation.new point
        #group.move! t
        # rotate
        tr = Geom::Transformation.rotation point, [0, 0, 1], rotation
        #group.transform! tr

        # updated transformation and group passed into measure.
        t = group.transformation

        # set layer and name
        group.name=name
        group.layer=layer
        group.material=material

        # set attributes
        group.set_attribute 'su2osm', 'space_type_name', space_type
        group.set_attribute 'su2osm', 'thermal_zone_name', thermal_zone
        group.set_attribute 'su2osm', 'building_story_name', building_story
        group.set_attribute 'su2osm', 'surface_group_type', surface_group_type

        # explode group contents
        oldGroup.explode

      end

      if group.layer.name == "su2osm - BuildingAndSpaceShadingGroup" or group.layer.name == "su2osm - SiteShadingGroup"

        #make or update group
        if group.layer.name == "su2osm - BuildingAndSpaceShadingGroup"
          shadingSurfaceType = "Building"
        else
          shadingSurfaceType = "Site"
        end

        shading_surface_group = make_shading_surface_group(group.name,t.origin.x.to_m,t.origin.y.to_m,t.origin.z.to_m,t.rotz*-1,shadingSurfaceType,"") #no parent for site and building shading
        #add to array of shading groups
        #make surfaces
        shading_surfaces = make_shading_surfaces(shading_surface_group,group)

      elsif group.layer.name == "su2osm - InteriorPartitionSurfaceGroup"
        # somehow warn the user that these need to be in a space, not at the top level
        puts "Top level group on interior partition layer is not valid. It will not be translated"
      elsif group.layer.name == "su2osm - Space"

        # store attributes for space for current render mode
        store_current_material_to_space_attributes(group)

        # gather space attributes
        space_type_name = group.get_attribute 'su2osm', 'space_type_name'
        space_type = space_type_hash[space_type_name.to_s]
        thermal_zone_name = group.get_attribute 'su2osm', 'thermal_zone_name'
        thermal_zone = thermal_zone_hash[thermal_zone_name.to_s]
        building_story_name = group.get_attribute 'su2osm', 'building_story_name'
        building_story = building_story_hash[building_story_name.to_s]

        #make or update space
        space = make_space(group.name,t.origin.x.to_m,t.origin.y.to_m,t.origin.z.to_m,t.rotz*-1,space_type,thermal_zone,building_story)
        #add to array of shading groups
        #make surfaces
        make_space_surfaces(space,group)

        #Making array of nested groups
        nested_groups = []

        # different method to get entities for group vs. component
        if group.class.to_s == "Sketchup::Group"
          entities = group.entities
        else group.class.to_s == "Sketchup::ComponentInstance"
        entities = group.definition.entities
        end

        entities.each do |group_entity|
          if group_entity.class.to_s == "Sketchup::Group" or group_entity.class.to_s == "Sketchup::ComponentInstance"
            group_entity.make_unique #this is only needed if a group was copied.
            nested_groups << group_entity
          end
        end #end of entities.each.do

        #process nested groups
        nested_groups.each do |nested_group|

          # get transformation
          nested_t = nested_group.transformation

          if nested_group.layer.name == "su2osm - BuildingAndSpaceShadingGroup"

            #make or update group
            space_shading_group = make_shading_surface_group(nested_group.name,nested_t.origin.x.to_m,nested_t.origin.y.to_m,nested_t.origin.z.to_m,nested_t.rotz*-1,"Space",space)
            #add to array of shading groups
            #make surfaces
            shading_surfaces = make_shading_surfaces(space_shading_group,nested_group)

          elsif nested_group.layer.name == "su2osm - InteriorPartitionSurfaceGroup"

            #make or update group
            interior_partition_group = make_interior_partition_group(nested_group.name,nested_t.origin.x.to_m,nested_t.origin.y.to_m,nested_t.origin.z.to_m,nested_t.rotz*-1,space)
            #add to array of shading groups
            #make surfaces
            interior_partition_surfaces = make_interior_partition_surfaces(interior_partition_group,nested_group)

          else
            puts "A nested group was not on valid layer. It will not be translated."
          end #end of if nested_group.layer

        end #end of nested_groups.each do

      else
        # should groups on other layers become spaces, or should they be ignored?
        # I think for now they should become spaces. Otherwise I need a script o add layers for user
        puts "A group was not on valid layer. It will not be translated."
      end #end of if group layer

    end #end of groups.each do

    # delete spaces that were no long in the SketchUp model. Don't perform this if merging selection only

    if not merge_selected_only

      @shading_groups.each do |shading_group|
        if not @current_shading_surface_groups.include? shading_group
          puts "removing #{shading_group.name}"
          shading_group.remove
        end
      end

      @interior_partition_groups.each do |interior_partition_group|
        if not @current_interior_partition_groups.include? interior_partition_group
          puts "removing #{interior_partition_group.name}"
          interior_partition_group.remove
        end
      end

      # I'm doing spaces last to avoid error about removing disconnected objects for nested groups.
      @spaces.each do |space|
        if not @current_spaces.include? space
          puts "removing #{space.name}"
          space.remove
        end
      end

    end #end of if not merge_selected_only

    #todo - warn user about loose top level surfaces

    #todo - also in loop through groups above warn if things are nested too deep

    #todo - could be nice to highlight things that are not valid by painting them or moving them to layer?

    #todo - would be nice to keep check similar to know if file was saved elsewhere since the import happened, offer to reload or cancel operation.

    #save the model
    @background_osm_model.save(merge_path,true)
    puts "model saved to #{merge_path}"

  end

end # module Sketchup::Su2osm

module TransformationHelper  # this was added to identify if a group in SketchUp has scale of -1

  def flipped_x?
    dot_x, dot_y, dot_z = axes_dot_products()
    dot_x < 0 && flipped?(dot_x, dot_y, dot_z)
  end

  def flipped_y?
    dot_x, dot_y, dot_z = axes_dot_products()
    dot_y < 0 && flipped?(dot_x, dot_y, dot_z)
  end

  def flipped_z?
    dot_x, dot_y, dot_z = axes_dot_products()
    dot_z < 0 && flipped?(dot_x, dot_y, dot_z)
  end

  private

  def axes_dot_products
    [
        xaxis.dot(X_AXIS),
        yaxis.dot(Y_AXIS),
        zaxis.dot(Z_AXIS)
    ]
  end

  def flipped?(dot_x, dot_y, dot_z)
    dot_x * dot_y * dot_z < 0
  end

end