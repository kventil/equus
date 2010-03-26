#!/opt/local/bin/ruby1.9

require 'net/http'                 
require 'socksify'
require 'nokogiri'  

require 'logger'

$LOG = Logger.new(STDOUT)

TCPSocket::socks_server = "127.0.0.1"
TCPSocket::socks_port = 8080    

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
    chapters.push(link[0]) if link[0].include? "fulltext.pdf"
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

################ MAIN #############

puts "Logged in: #{loggedIn?}"

chapters = []        

content = fetch("/content/kq0323/?p=cf5010e25e1e4d66885de488f2737e4c&pi=17")

match = content.match(/<h2 class="MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName">([^<]+)<\/h2>/)
booktitle = $1.strip 

chapters = extractChapterLinks(content) 

puts "Fetched #{chapters.size} chapters"

puts booktitle 










