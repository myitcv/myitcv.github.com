desc "Build layouts"
task :build do
  system("for i in ./_layouts_haml/*.haml; do [ -e $i ] && n=${i%.*} && haml $i ./_layouts/${n##*/}.html; done")
  system("haml index.haml index.html")
end

task :run do
  Rake::Task["build"].invoke
  system("jekyll serve --future --config _config.yml,_config_dev.yml")
end

