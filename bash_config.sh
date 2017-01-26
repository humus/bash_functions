#!/bin/bash

export PS1="\[\033[33m\]\w\[\033[36m\]\$(__git_ps1)\[\033[0m\]\n$ "

alias status='git status --short'

## JEE variables
export tomcat_dir=$(find $HOME/jee -type d -name 'apache-tomcat-*')
export maven_dir=$(find $HOME/jee -type d -name 'apache-maven-*')
export jdk8_dir=$(find $HOME/jee -type d -name 'jdk1.8*')
export jdk7_dir=$(find $HOME/jee -type d -name 'jdk1.7*')

export JAVA_HOME=$jdk8_dir

if [[ -n "$jdk8_dir" ]]; then
  export PATH=$PATH:$maven_dir/bin:$jdk8_dir/bin
else
  echo 'something is wrong'
fi


function m() {
  mvn -Dmaven.repo.local=$HOME/jee/m2/repo $@
}
