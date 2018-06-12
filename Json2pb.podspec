Pod::Spec.new do |s|
  s.name          =  "Json2pb"
  s.summary       =  "Objective-C implementation of JSON to/from Protobuf convertor."
  s.version       =  "1.0.0"
  s.homepage      =  "https://github.com/rannger/json2pb"
  s.license       =  { :type => 'MIT', :file => 'LICENSE.txt' }
  s.author        =  { "Liang Rannger" => "liang.rannger@gmail.com" }
  s.source        =  { :git => "https://github.com/rannger/json2pb.git", :tag => "1.0.0" }
  s.platform      =  :ios, '7.0'
  s.source_files  =  'Classes/*.{h,m}'
  s.requires_arc  =  true
  s.dependency       'Protobuf'
  s.dependency       'Jansson'
end
