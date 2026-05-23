platform :osx, '14.0'
use_frameworks!

target 'GravieCopy' do
  # GRDB with SQLCipher encryption — pulled from git since the trunk only carries v3.7.0.
  # The SQLCipher subspec links against the SQLCipher pod instead of the system sqlite3.
  pod 'GRDB.swift/SQLCipher', :git => 'https://github.com/groue/GRDB.swift.git', :tag => 'v7.10.0'
end
