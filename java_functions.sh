
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
  make_classpath_entry "$jars:target/classes:target/test-classes"
}


parse_classpath_from_pom() {
  grep -E 'jar$' | grep -E 'jar[:;]' | tr '\\' /
}

make_classpath_entry() {
  echo "Class-Path# $1" | sed -r 's/([ ;])([A-Z]):/\1\/\2#/g;s/[;:]/ /g' |
  sed -r 's/([[:alnum:]])#/\1:/g;s/(.{65})/&@/g' |
  tr '@' '\n' | sed -r '2,$s/^/ /'
}

pmv() {
  source=$1
  target=$2
  mkdir -p "$target"/"$(dirname $source)"
  mv "$source" "$target"/"$(dirname $source)"/
}

move_to_target() {
  mkdir -p target/{test-classes,classes}
  find_and_move_classfiles src/main/java "$(pwd)/target/classes/"
  find_and_move_classfiles src/test/java "$(pwd)/target/test-classes/"
}

find_and_move_classfiles() {
   dirsrc=$1
   dirdest=$2
  (
    cd $dirsrc
    find -name '*.class' |
    while read f; do
      pmv $f $dirdest
    done
  )
}

drop_class_file() {
  find -name $1*.class | while read f; do
    rm $f
  done
}


cpjar_javac() {
  javac -cp classpath.jar -g -sourcepath 'src/main/java;src/test/java' \
    "$(find -name $1.java -o -name $1)"
  if [[ "$?" -ne "0" ]]; then drop_class_file $1; return 1; fi;
  move_to_target
}

cpjar_javax() {
  java -cp "target/test-classes;target/classes;classpath.jar" $1
}

cpjar_junit() {
  java -cp "target/test-classes;target/classes;classpath.jar" \
    org.junit.runner.JUnitCore $1 |
  grep -E -v 'at (org\.)?junit|at sun\.reflect|at java.lang.reflect'
}

jar_for_current_project() {
  jar_for_project $(pwd)/pom.xml
}

#example: 
#jar_for_project /c/home/r/code/seleniumtests/pom.xml

