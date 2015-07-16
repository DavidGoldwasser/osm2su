osm2su
======

Experimental light weight SketchUp Plugin to create, inspect and edit OSM models.

This duplicates the functionality of the experimental section of the OpenStudio SketchUp Plugin userscripts. I wanted set it up as a seperate plugin so it can be used without the main OpenStudio SketchUp Plugin installed or enabled. OpenStudio is still required, but is only used for importing OSm files and merging changes back to an OSM. The first time osm2su is used the user needs to define the path to openstuido.rb. This can be updtaed when newer versions of OpenStudio are installed. I tested this with boht SU 2015 and also SketchUp 8.

This is just a pet project to see how a light weigh plugin handles, what the workflow could be like as well as the performance. Unlike the main OpenStudio plugin where you don't save the SketchUp file. With osm2skp, you have a native SketchUP model that you can send to someone who doesn't even have OpenStudio or osm2skp. They can edit it, send it back to you and you can then merge it back to an OSM. The tool basicilly make a structure SketchUp file where spaces, shading surface groups, and interior partion groups become SketchUp gropus, organized by layers. 

Next Steps:
x add stub space attributes as materials and add render modes for things like space types, thermal zones and stories.
x export space attributes back out to osm
x allow the user to use built in SketchUp paintbuicket/eyedropper to change space attributes
- add additional render modes, idealy based off of measures for things like render by air loops or lighting LPD, etc. This coudl be extended by users. I need to think aobut how measure will communicate back to osm2su.
- add surface attributes
- import is already fast. Need to imporve merge as it is slow. That is why I enabled the ability to only merge selected spaces if you know which spaces were edited.
- add more robst handling for problmenatic geometry.
- translate sub-surfaces in as components? among other things this would support windows that are not planer with base surface.
- Consider indirect selection model where user can easily select across groups.
- (note: as this is just an experiment, it is possible that none of the next steps will be implemented)
