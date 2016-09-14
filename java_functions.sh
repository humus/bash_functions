
jar_for_project() {
  buildfile=$1
  if [[ "$#" -lt "1" ]]; then exit 1; fi
  printf "\e[33mParsing dependencies\n\e[0m"
  jars=$(mvn -f $buildfile dependency:build-classpath | parse_classpath_from_pom)
  dir=$(project_cache_dir $buildfile)
  printf "\e[33mCreating manifest\n\e[0m"
  build_manifest $jars > $dir/manifest
  printf "\e[33mcreating jar\n\e[0m"
  jar -cmf $dir/manifest $dir/classpath.jar
  destdir=$(dirname $buildfile)/classpath.jar
  printf "\e[32mcopiando classpath.jar a $destdir \n\e[0m"
  cp $dir/classpath.jar $destdir
}

project_cache_dir() {
  projectdir=$(dirname $1)
  cache_dir="$HOME/.cache/$(echo $projectdir | sed 's#/#_#g')"
  mkdir -p $cache_dir
  echo $cache_dir
}

build_manifest() {
  jars=$1
  echo "Archiver-Version: java_functions"
  echo "Manifest-Version: 1.0"
  echo "Created-By: java_functions"
  echo "Main-Class: org.junit.core.JUnitCore"
  make_classpath_entry "$jars"
}


parse_classpath_from_pom() {
  grep -E 'jar$' | grep -E 'jar[:;]' | tr '\\' /
}

make_classpath_entry() {
  echo "Class-Path# $1" | sed -r 's/([ ;])([A-Z]):/\1\/\2#/g;s/[;:]/ /g' |
  sed -r 's/([[:alnum:]])#/\1:/g;s/(.{65})/&@/g' |
  tr '@' '\n' | sed -r '2,$s/^/ /'
}

#example: 
#jar_for_project /c/home/r/code/seleniumtests/pom.xml

