toPlaceInPath = "BadApple!-WOS.lua"
fileToPlacePath = "BAPrebuilt.txt"
targetPre = "\t\t"
target = "--insertMarker_renderFrames"
outputFilePath = "preBuilt-BadApple!-WOS.lua"

with open(toPlaceInPath,'r') as toPlaceInFile,open(fileToPlacePath,'r') as fileToPlace:
  lines = toPlaceInFile.readlines()
  
  if targetPre+target+"\n" in lines:
    lines[lines.index(targetPre+target+"\n")] = targetPre+fileToPlace.read()+"\n"
    with open(outputFilePath,'w') as outputFile: outputFile.writelines(lines)
  else: raise Exception("target not found")