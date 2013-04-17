desc "Build layouts"
task :build do
  system("for i in ./_layouts_haml/*.haml; do [ -e $i ] && n=${i%.*} && haml $i ./_layouts/${n##*/}.html; done")
  system("haml index.haml index.html")
  system("haml lbscoding/info/index.haml lbscoding/info/index.html")
  system("haml lbscoding/session_1/index.haml lbscoding/session_1/index.html")
end

task :run do
  Rake::Task["build"].invoke
  system("jekyll --pygments --no-lsi --safe --server --future")
end

