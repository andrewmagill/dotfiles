# e.g. $ solrpanel nano 2090 3333
function solrpanel() {
  ssh -L $3:localhost:$2 $1
}
