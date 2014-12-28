# Initial test of moving OpenStudio SketchUp Plugin Experimental Workflow into a light weight stand alone script

require 'sketchup.rb'
require 'extensions.rb'
require 'langhandler.rb'

module Sketchup::Su2osm

$exStrings = LanguageHandler.new("su2osm.strings")

su2osmExtension = SketchupExtension.new(
  $exStrings.GetString("su2osm"),
  "su2osm/su2osmScripts.rb")

su2osmExtension.description = $exStrings.GetString(
  "Adds su2osm of tools")
su2osmExtension.version = "0.0.1"
su2osmExtension.creator = "David Goldwasser"
su2osmExtension.copyright = "2015, David Goldwasser"

Sketchup.register_extension su2osmExtension, true

end # module Sketchup::Su2osm
