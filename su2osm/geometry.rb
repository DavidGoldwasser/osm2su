# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'

module Sketchup::Su2osm

  def self.create_sketchup_groups_from_diagram

    # gather user input
    prompts = ["Floor to Floor Height?", "Number of Stories?"]
    defaults = ["10'", 1]
    input = UI.inputbox(prompts, defaults, "Create SketchUp Groups from Diagram.")
    height = input[0]
    num_floors = input[1]

    # error check input to make sure positive values
    valid_input = true

    #convert string to SketchUp length
    height = height.to_l

    if height <= 0
      UI.messagebox("Height must be greater than 0 meters.")
      valid_input = false
    end

    num_floors = num_floors.to_i
    if num_floors < 1
      UI.messagebox("Number of floors must be greater than or equal to 1.")
      valid_input = false
    end

    # get sketchup model
    suModel = Sketchup.active_model
    selection = suModel.selection

    status = suModel.start_operation('Create SketchUp Groups from Diagram', true)

    # save selection
    saved_selection = []
    selection.each {|e| saved_selection << e}

    valid_diagram = true

    # canel if there is no selection (remove OpenStudio objects first)
    if selection.empty?
      UI.messagebox("No loose geometry is selected, please select objects to extrude into OpenStudio spaces")
      valid_diagram = false
    end

    # cancel if all faces in selection are not horizontal, flip reversed faces
    expected_normal = Geom::Vector3d.new 0,0,-1
    inv_expected_normal = Geom::Vector3d.new 0,0,1
    status = 0
    selection.each do |index|
      if index.typename == "Face"
        if index.normal != expected_normal
          if index.normal == inv_expected_normal
            puts "reversing face normal of #{index}"
            flip = index.reverse!
          else
            status = 1
          end
        end
      end
    end #end of selection.each do

    if status == 1
      UI.messagebox("Not all selected surfaces are horizontal, please limit selection to horizontal surfaces")
      valid_diagram = false
    end

    if valid_diagram and valid_input # skip over if not valid selection for space diagram or valid input

      # sort SketchUp selection and pass this to OpenStudio
      sel_sort = Sketchup.active_model.selection.to_a
      sel_sort.delete_if {|e| not e.is_a?(Sketchup::Face) }
      sel_sort.sort! {|a,b|
        ([a.vertices.min{|v1,v2| v1.position.y <=> v2.position.y }.position.y,
          a.vertices.min{|v1,v2| v1.position.x <=> v2.position.x }.position.x] <=>
            [b.vertices.min{|v1,v2| v1.position.y <=> v2.position.y }.position.y,
             b.vertices.min{|v1,v2| v1.position.x <=> v2.position.x }.position.x] )
      }

      faces = []
      sel_sort.each { |entity| faces << entity if entity.class == Sketchup::Face }

      # create or confirm layers
      layers = suModel.layers
      new_layer_diagram = layers.add("su2osm - Space Diagrams")
      new_layer_spaces = layers.add("su2osm - Space")

      # add loop to create multiple floors. Will need to create new stories and adjust z values
      for floor in (1..num_floors)

        # rest room counter
        rm = 0

        # loop through faces in the selection
        faces.each do |face|

          # get vertices
          pts = face.outer_loop.vertices

          # make group
          group = Sketchup.active_model.entities.add_group

          #put on space layer
          group.layer = new_layer_spaces

          # create face in group
          entities = group.entities
          face = entities.add_face pts

          # transform group to adjust for number of floors
          base_height = height*(floor-1)
          new_transform = Geom::Transformation.new([0,0,base_height])
          group.transformation = new_transform

          # extrude surface by floor height
          status = face.pushpull height*-1, false

          rm = rm + 1
          # set space name
          if faces.length < 100
            padded_room_number = "Space " + floor.to_s + "%02d" % rm
          else
            padded_room_number = "Space " + floor.to_s + "%03d" % rm
          end

          # name group
          group.name = padded_room_number

        end # end of selection loop

      end # end of floor loop

      # turn off layer visibility
      new_layer_diagram.visible  = false

      # make group out of selection and put onto OS Loose Geometry Layer
      thermal_diagram = Sketchup.active_model.entities.add_group(saved_selection)
      thermal_diagram.layer = new_layer_diagram

      status = suModel.commit_operation

    end #end of if valid_diagram
      
  end

  def self.project_loose_geometry_onto_sketchup_groups

    # gather user input
    prompts = ["Project Only Selected Loose Geometry?"]
    defaults = [false]
    list = ["true|false"] # todo - get true option functioning. Bug exists in OpenStudio plugin as well
    input = UI.inputbox(prompts, defaults, list, "Project Loose Geometry onto SketchUp Groups.")
    selection_only = input[0]

    # get sketchup model
    suModel = Sketchup.active_model
    entities = suModel.active_entities
    selection = suModel.selection
    groups = []
    components = []

    status = suModel.start_operation('Project Loose Geometry onto SketchUp Groups', true)

    if selection_only == "false" # comes out of input as string vs. bool
      selection = entities
    end

    # save selection
    saved_selection = []

    selection.each do |entity|
      if entity.class.to_s == "Sketchup::Face" or entity.class.to_s == "Sketchup::Edge"
        saved_selection << entity
      end
    end

    # get groups in model
    entities.each do |entity|
      if entity.class.to_s == "Sketchup::Group"
        entity.visible = false
        groups << entity
      end
      if entity.class.to_s == "Sketchup::ComponentInstance"
        puts "geometry won't be altered for #{entity.name}, it is a component instance."
        entity.visible = false
        components << entity
      end
    end #end of entities.each do

    # loop through groups intersecting with selection
    groups.each do |group|
      group.visible = true
        group.entities.intersect_with(true, group.transformation, group.entities.parent, group.transformation, false, selection.to_a)
      group.visible = false
    end #end of groups.each do

    #unhide everything
    groups.each do |group|
      group.visible = true
    end
    components.each do |component|
      component.visible = true
    end

    # create or confirm layer called "OpenStudio - Project Loose Geometry" exists
    layers = suModel.layers
    new_layer = layers.add("su2osm - Project Loose Geometry")

    # turn off layer visibility
    new_layer.visible  = false

    # make group out of selection and put onto OS Loose Geometry Layer
    loose_geometry = Sketchup.active_model.entities.add_group(saved_selection)
    loose_geometry.layer = new_layer

    status = suModel.commit_operation

  end

end # module Sketchup::Su2osm
