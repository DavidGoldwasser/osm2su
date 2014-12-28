# initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'

module Sketchup::Su2osm

  def self.set_path_to_openstudio

      puts ""
      puts ">>Set and Store the Path used for OpenStudio installation"

      # gather user input
      prompts = ["Path to openstudio.rb"]
      defaults = ['C:/Program Files/OpenStudio 1.5.3/Ruby/openstudio.rb'] #should probably allow the user to browse vs. using a string, need to figure out backslash issue
      input = UI.inputbox(prompts, defaults, "su2osm Configure Dialog.")
      openstudio_path = input[0]

      result = Sketchup.write_default "su2osm","openstudio_path", openstudio_path

      test = Sketchup.read_default("su2osm","openstudio_path")
      puts "Path to OpenStudio set to #{test}"

      begin
        require test.to_s
      rescue LoadError
        UI.messagebox('Could not load OpenStudio, please verify the path.')
      end
  end

end # module Sketchup::Su2osm
