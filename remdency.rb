#!/usr/bin/env ruby

# remdency - XCode linker dependency removal tool

# installation
#  $ sudo chmod +x remdency.rb
#  $ sudo mv remdency.rb /usr/local/bin/remdency

# usage example
#  $ remdency -p Pod1 Pod2 -t Target1 Target2 Target3
#    (remove Pod1 and Pod2 dependencies from Target1, Target2 and Target3)

# run remdency in directory containing Pods directory (or Podfile)

# the journey starts here...

# knump needs this to work

def createPrefixTable(pattern)
  if (!pattern) then
    return
  end

  prefix = Array.new((pattern.length),0)
  j = 0
  prefix[0] = 0

  for i in 1...(pattern.length)
    if pattern[i] == pattern[j]
      prefix[i] = j
      j = j+1
    else
      while true
        j = prefix[j]
        if j == 0 then
          break
        end
        if pattern[i] == pattern[j]
          prefix[i] = prefix[j]
          break
        end
      end
    end
  end
  return prefix
end

# because it will be faster this way
# (if we are looking just for a single char)

def findchar(char, text, start, endpos)

  iTex = start
  iRes = 0
  results = Array.new(0,0)

  while true
    if iTex > endpos then
      return results
    end

    if text[iTex] == char then
      results[iRes] = iTex
      iRes = iRes + 1
    end

    iTex = iTex + 1
  end
end

def log (message, type)

  if type == "error" then
    puts "\n (!) #{message}\n"
    return
  end

  if type == "debug" then
    puts "\n (D) #{message}\n"
    return
  end

end

# the heart of it all

def knump (pattern, text, start, endpos, debug_trigger)

  debug = "none"

  if debug_trigger == true then
    debug = "debug"
  end

  if (!pattern) || (!text) then
    log("No pattern input or no string/file input.", "error")
    return []
  end

  if pattern.length == 0 || text.length == 0 then
    log("Pattern or text of length zero.", "error")
    return []
  end

  if pattern.length == 1 then
    log("Pattern is a single character. Using ordinary naive search.", debug)
    return findchar(pattern, text, start, endpos)
  end

  if start >= endpos then
    if (pattern.length == 1) && (start == endpos) then
      if text[start] == pattern[0] then
        return [0]
      else
        log("Char in text differs from pattern char.", debug)
        return []
      end
    end
    log("Start position is after end position. Seriously?", debug)
    return []
  end

  if start < 0 || endpos >= text.length then
    log("Start position is less than zero or end position after last\n" +
        "position in text (y u do dis... dolan pls)", "error")
    return []
  end

  prefix = createPrefixTable(pattern)

  log("Prefix table created: [#{prefix}].", debug)

  results = Array.new(0,0)

  iRes = 0
  iPat = 0 # position in pattern
  iPtx = 0 # position of pattern check in text
  iTex = start # position in text

  while true

    if iTex > endpos then
      log("Main loop reached end position: #{endpos}.", debug)
      break
    end

    if text[iTex] != pattern[0] then
      iTex = iTex + 1
    else
      log("Partial match at: #{iTex}. Enter secondary loop.", debug)
      iPtx = iTex
      iPat = 0

      while true

        if iPtx > endpos then
          log("Reached end at: #{endpos} during partial match.", debug)
          return
        end

        if text[iPtx] == pattern[iPat] then
          iPtx = iPtx + 1
          iPat = iPat + 1
        else
          iPtx = iPtx + prefix[iPat]
          iPat = prefix[iPat]
        end

        if iPat >= pattern.length then
          results[iRes] = iTex
          iRes = iRes + 1
          iTex = iTex + prefix[iPat - 1] + 1
          log("We've got a match! Advance by #{iTex} and continue.", debug)
          break
        end

        if iPat == 0 then
          log("We have reached root of pattern. Advance by 1.", debug)
          iTex = iTex + 1
          break
        end

      end

    end
  end
  return results
end

def validate str
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a
  str.chars.detect {|ch| !chars.include?(ch)}.nil?
end

def findChar(charToFind, whereToFind, position, increment)
  i = position
  charPos = -1

  loop do
  	if (i >= whereToFind.length) || (i < 0)
      break
    end

    if whereToFind[i] == charToFind
      charPos = i
      break
    end

    i = i + increment
  end

  return charPos
end

def findCharBefore(charToFind, whereToFind, position)
  return findChar(charToFind,whereToFind,position,-1)
end

def findCharAfter(charToFind, whereToFind, position)
  return findChar(charToFind,whereToFind,position,1)
end

def process(fileName, podName)
  file = File.open(fileName, "r") || true rescue false

  if !file
    print("(!) Could not open file: ", fileName, ".\n")
    return nil
  end

  data = file.read
  file.close

  pos = -podName.length
  posOld = -podName.length

  loop do
    pos = pos + podName.length
    posOld = pos

    dataToFind = data[pos, data.length - pos]
    knumpResults = knump(podName, dataToFind, pos, (data.length - pos) - 1, false)
    pos = knumpResults[0]

    if !pos
  	  print("Ended search in file ", fileName, ". No changes will be made.\n")
      return nil
    end

    pos = posOld + pos

    if !validate data[pos+podName.length,1]
      break
    end
  end

  quoteBegin = findCharBefore("\"",data,pos)
  quoteEnd = findCharAfter("\"",data,pos)

  if (quoteEnd == -1) || (quoteBegin == -1) || (quoteBegin == quoteEnd)
    print("(!) Unexpected data found. No changes will be made in ", fileName, ". Try removing ", podName, " references manually.\n")
    return nil
  else
  	lineBegin = findCharBefore("\n",data,pos)
    lineEnd = findCharAfter("\n",data,pos)

  	if (lineBegin <= quoteBegin) && (quoteEnd <= lineEnd) && (quoteBegin <= quoteEnd)
      if (data[lineBegin, lineEnd - lineBegin + 1] =~ /install_resource/) != nil
      	newData = data[0,lineBegin] + data[lineEnd,data.length - lineEnd]
      	if newData[newData.length - 1] == data[data.length - 1]
      	  return newData
      	else
          print("(!) Internal bug, stopping due to possible data loss.\n")
          return nil
        end
      end
    end

    nextQuote = findCharAfter("\"",data,quoteEnd + 1)

    if (nextQuote > quoteEnd)
      if (data[quoteEnd, nextQuote - quoteEnd + 1] =~ /-isystem/) || (data[quoteEnd, nextQuote - quoteEnd + 1] =~ /-l/)
        newData = data[0,quoteBegin] + data[nextQuote,data.length - nextQuote]
      	if newData[newData.length - 1] == data[data.length - 1]
          print("\n---\nDeleting line:\n", data[quoteBegin, nextQuote - quoteBegin + 1], "\nin file ", fileName, ".\n---\n")
      	  return newData
      	else
      	  print("(!) Internal bug, stopping due to possible data loss.\n")
      	  return nil
        end
      end
    end

    return data[0,quoteBegin] + data[quoteEnd + 1,data.length - quoteEnd - 1]
  end
end

def procesAll(list, podName)
  i = 0
  safe = -1 # counter to prevent infinite loops in case of file write errors (let's hope it never gets here)

  loop do
    if i >= list.length
      break
    end
    loop do
      if safe == 1000
        print("(!) Assumed file write error, breaking infinite loop (file: ", list[i], ").\n")
        break
      end
      safe += 1

      result = process(list[i],podName)
      
      if !result
        break
      else
          file = File.open(list[i], "w") || true rescue false

          if !file
            print("(!) Could not open file: ", list[i], "\n")
            break
          end

          file.write(result)
          file.close
      end
    end
    i += 1
  end
end

def processArgs()

  if ARGV.length == 0
    print("\n\033[1mRemdency\033[m - XCode linker dependency removal tool\n\n")
    print("\033[1mInstallation\033[m\n\n")
    print("  $ sudo chmod +x remdency.rb\n")
    print("  $ sudo mv remdency.rb /usr/local/bin/remdency\n\n")
    print("\033[1mUsage example\033[m\n\n")
    print("  $ remdency -p Pod1 Pod2 -t Target1 Target2 Target3\n")
    print("    \033[2mRemove Pod1 and Pod2 dependencies from Target1, Target2 and Target3.\033[m\n\n")
    print("\033[1mUsage note\033[m\n\n")
    print("   Run remdency in directory containing Pods directory (or Podfile).\n\n")
    print("\033[1mAuthor\033[m\n\n")
    print("   Stjepan Poljak (2018)\n\n")
    print("\033[1mComments\033[m\n\n")
    print("   Use remdency on your own responsibility. It should work, but it is still\n")
    print("   not well tested. You are free to modify and distribute the source as you\n")
    print("   please. Remdency is based on my knump program, a Knuth - Morris - Pratt\n")
    print("   search algorithm implementation in Ruby. It was written during a morning\n")
    print("   coffee with my fiancee, so it may also need some correctness testing.\n\n")
    exit
  else
    print("\n---\nDependency removal for XCode linker by Stjepan Poljak (2018).\n---\n\n")
  end

  podsToRemove = Array.new(0,0)
  targetsToConsider = Array.new(0,0)

  targets = false
  pods = false

  targetsCounter = 0
  podsCounter = 0

  targetFilePaths = Array.new(0,0)

  ARGV.each do |a|

    if targets && a != "-p"
      targetsToConsider[targetsCounter] = a
      targetsCounter += 1
    end

    if pods && a != "-t"
      podsToRemove[podsCounter] = a
      podsCounter += 1
    end

    if a == "-t"
      targets = true
      pods = false
    end

    if a == "-p"
      pods = true
      targets = false
    end
  end

  print("Will remove:\n")

  podsToRemove.each do |a|
    print("  ", a, "\n")
  end

  print("\nFor targets:\n")

  targetsCounter = 0

  targetsToConsider.each do |a|
    
    print("  ", a, "\n")
    
    targetFilePaths[targetsCounter] = "Pods/Target Support Files/Pods-" ++ a ++ "/Pods-" ++ a ++ "-resources.sh"
    targetsCounter += 1
    targetFilePaths[targetsCounter] = "Pods/Target Support Files/Pods-" ++ a ++ "/Pods-" ++ a ++ ".debug.xcconfig"
    targetsCounter += 1
    targetFilePaths[targetsCounter] = "Pods/Target Support Files/Pods-" ++ a ++ "/Pods-" ++ a ++ ".release.xcconfig"
    targetsCounter += 1

  end

  print("\nWill read/write files:\n")

  targetFilePaths.each do |a|
    print("  ", a, "\n")
  end

  print("\n")

  podsToRemove.each do |a|
    print("Removing ", a, ".\n")
    procesAll(targetFilePaths, a)
  end

  print("\n\nDone!\n\n")

end

processArgs()