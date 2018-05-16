Pod::Spec.new do |s|


  s.name         = "UNOAspect"
  s.version      = "0.0.1"
  s.summary      = "A short description of UNOAspect."


  s.homepage     = "git@gitlab.intebox.com:Mobile_IOS"
  s.license      = "MIT"
  s.author    = "jinmintong"

  s.ios.deployment_target = "7.0"

  s.source       = { :path => "." }

  s.source_files  = "UNOAspect/vender/*.*"
  s.public_header_files = "UNOAspect/vender/*.h"

end
