package tnv.k8s

class Point {
  float x,y,z
}

def checkOutFrom(repo) {
  git url: "git@github.com:jenkinsci/${repo}"
}

return this