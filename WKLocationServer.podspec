

Pod::Spec.new do |spec|


  spec.name         = "WKLocationServer"
  spec.version      = "0.0.1"
  spec.summary      = "WKWebView解析定位，获取用户所在地区"
  spec.description  = <<-DESC
                        WKWebView解析定位，获取用户所在地区
                   DESC

  spec.homepage     = "https://github.com/Cingjin"

  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "yuxingjin" => "15327288437@163.com" }

  spec.source       = { :git => "https://github.com/Cingjin/WKLocationServer.git", :tag => "#{spec.version}" }

  spec.source_files = "LocationServer/**/*.{h,m}"

  s.requires_arc    = true

end
