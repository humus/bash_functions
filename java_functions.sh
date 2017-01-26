
jar_for_project() {
  buildfile=$1
  if [[ "$#" -lt "1" ]]; then exit 1; fi
  parse_dependencies
  dir=$(project_cache_dir $buildfile)
  create_jar
  move_classpath_jar
}

parse_dependencies() {
  pyellow "Parsing dependencies"
  jars=$(mvn -f $buildfile dependency:build-classpath | parse_classpath_from_pom)
}

move_classpath_jar() {
  destdir=$(dirname $buildfile)/classpath.jar
  pgreen "copiando classpath.jar a $destdir"
  cp $dir/classpath.jar $destdir
}

create_jar() {
  pyellow "Creating manifest"
  build_manifest $jars > $dir/manifest
  pyellow "creating jar"
  jar -cmf $dir/manifest $dir/classpath.jar
}

pgreen() {
  printf "\e[32m"
  printf "$@\n"
  printf "\e[0m"
}

pyellow() {
  printf "\e[33m"
  printf "$@\n"
  printf "\e[0m"
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
  find_and_move_classfiles src/main/java "$(pwd)/target/classes"
  find_and_move_classfiles src/test/java "$(pwd)/target/test-classes"
}

find_and_move_classfiles() {
  dirsrc=$1
  dirdest=$2
  if [[ ! -e $dirsrc ]]; then return; fi
  (
    cd $dirsrc
    find . -name '*.class' |
    while read f; do
      pmv $(echo $f | sed 's#./##') $dirdest
    done
  )
}

drop_class_file() {
  find -name $1*.class | while read f; do
    rm $f
  done
}

cpjar_javac_simple() {
  javac -cp classpath.jar -g -sourcepath "$(localsourcepath)" $*

  if [[ "$?" -ne "0" ]]; then drop_class_file $1; return 1; fi;

  move_to_target
}


cpjar_javac() {
  javac -cp classpath.jar -g -sourcepath "$(localsourcepath)" \
    "$(find src -name $1.java -o -name $1)"
  if [[ "$?" -ne "0" ]]; then drop_class_file $1; return 1; fi;

  move_to_target
}

cpjar_javax() {
  java -cp "target/test-classes;target/classes;classpath.jar" $1
}

cpjar_junit() {
  java -cp "target/test-classes:target/classes:classpath.jar" \
    org.junit.runner.JUnitCore $1 |
  grep -E -v 'at (org\.)?junit|at sun\.reflect|at java.lang.reflect'
}

  jar_for_current_project() {
    jar_for_project $(pwd)/pom.xml
  }

  mnew() {
    params=()
    if [[ "$#" -lt "2"  ]]; then return 1; fi
    while [[ "$#" -gt 2 ]]; do
      params+=("$1")
      shift
    done
    group=$1
    artifact=$2
    mvn archetype:generate -B ${params[@]} \
      -Dmaven.archetypeArtifactId=maven-archetype-quickstart\
      -DartifactId=$artifact -DgroupId=$group
    printf "command was\n mvn archetype:generate -B ${params[@]} -Dmaven.archetypeArtifactId=maven-archetype-quickstart -DartifactId=$artifact -DgroupId=$group \n"
  }

cpjar_feature() {
  if [[ "$#" -lt "1" ]]; then return 1; fi
 dir=$(project_cache_dir $(pwd)/pom.xml)
  mkdir -p $dir
  tmp=$(mktemp)
  java -cp "$(localclasspath)" cucumber.api.cli.Main -g $(glue_dir $(find src -name $1)) \
  --snippets camelcase -p pretty $(find src -name $1) |
  tee $tmp
  sed '1,/You can implement/d' > $dir/$(basename $1).txt $tmp
  rm $tmp
}

glue_dir() {
  dirname $1 | sed 's#src/\(main\|test\)/resources/##'
}

localsourcepath() {
  sourcepath='src/main/java:src/test/java'
  if [[ $(uname -s) =~ 'NT' ]]; then
    sourcepath=$(echo $sourcepath | sed 's/:/;/g')
  fi
  echo $sourcepath
}

localclasspath() {
  classpath='target/classes:target/test-classes:classpath.jar'
  if [[ $(uname -s) =~ 'NT' ]]; then
    classpath=$(echo $classpath | sed 's/:/;/g')
  fi
  echo $classpath
}


start_autotest_cycle() {
  inotifywait -e modify -q -mr --exclude='target|.git/'  --format '%w %f' . |

  while read dir file; do
    if [[ $file == *".class"* ]]; then
      continue;
    fi
    files=$dir$file
    if [[ $dir == *"/main/"* ]]; then
      testfile=$(find src/test -name ${file/.java/Test.java} -o -name ${file/Impl.java/Test.java})
      files="$dir$file $testfile"
    fi

    cpjar_javac_simple $files

    if [[ "$?" -eq "0" && -n "$testfile" ]]; then 
      cpjar_junit $(echo $testfile | sed 's#\.\?/\?src/test/java/##;s#/#.#g;s#\.java##')
    else
      echo foo
    fi

  done;
}

#example:
#jar_for_project /c/home/r/code/seleniumtests/pom.xml

