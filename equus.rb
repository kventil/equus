#!/opt/local/bin/ruby1.9

require 'net/http'                 
require 'socksify'
require 'logger'
require 'asciify'        


$LOG = Logger.new(STDOUT)




#tests if "Recognized as" to determine if an institunional login exists
def loggedIn?
  main = fetch "/home/main.mpx"
  return true if main.include? "Recognized as:"
  return false                 
end

def fetch(content)
  resp = nil
  Net::HTTP.start("springerlink.com") { |http|
    resp = http.get(content) 
  }                          
  raise Exception.new(resp.message + ":" + content) if resp.code != "200"                      
  return resp.body  
end 

#rekursiv alle kapitel holen
def extractChapterLinks(content)
  chapters = []    

  content.scan(/href="(.+?.pdf)"/).each{
    |link|            
    if link[0].include? "fulltext.pdf"
      chapters.push(link[0]) 
      $LOG.debug(link[0])
    end
  }

  #look for next page
  match = content.match(/<a href="([^"]+)">Next<\/a>/)
  if match.nil?                                          
    return chapters 
  else
    $LOG.info("Found next Page")
    return chapters + extractChapterLinks(fetch(match[1].gsub("&amp;", "&")))
  end
end                         

def fetchBookCover(contentlink,chapters)  
  content = fetch(contentlink)

  sublink = contentlink.match(/\/content\/[a-z0-9\-]+\//)[0]
  $LOG.debug(sublink)

  if content.include?("front-matter.pdf")           
    $LOG.debug("Found front-matter.pdf")
    chapters.insert(0,sublink + "front-matter.pdf") 
  end                                 

  if content.include?("back-matter.pdf")
    $LOG.debug("Found back-matter.pdf")
    chapters.push(sublink + "back-matter.pdf")  
  end
end

    

useSocks = true 
socks_server = "127.0.0.1"
socks_port = "8080"

if useSocks
  TCPSocket::socks_server = socks_server
  TCPSocket::socks_port = socks_port
end



#inputLink = "http://springerlink.com/content/m23151/?p=a0a1ea6390424b73854eabb657ad1fcd&pi=29"
contentlink = "/content/m23151/?p=a0a1ea6390424b73854eabb657ad1fcd&pi=29"

if !loggedIn?
  $LOG.error("Not logged in")
  exit
end

content = fetch(contentlink)

$LOG.debug("Fetched #{content.size} bytes")

booktitle = content.match(/<h2 class="MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName">([^<]+)<\/h2>/)[1].strip 
outputtitle = (booktitle.gsub(" ","_") + ".pdf").asciify

$LOG.info("Booktitle: #{booktitle}")
$LOG.info("Savefile: #{outputtitle}")

chapters = extractChapterLinks(content) 

$LOG.info("Chapters: #{chapters.size}")


fetchBookCover(contentlink,chapters)
counter = 1


fileList = []
chapters.each{
  |chapter|                              
  File.open("#{counter}.pdf","wb"){
    |file|
    file.write(fetch(chapter))
    fileList.push("#{counter}.pdf")
  }          
  counter += 1
} 



if !system("pdftk #{fileList.join(" ")} cat output #{outputtitle}")
  $LOG.error("pdftk failed")
else
  puts "All parts merged to #{outputtitle}" 
end

if !system("rm #{fileList.join(" ")}")
  $LOG.error("failed deleting temporary files")
end












