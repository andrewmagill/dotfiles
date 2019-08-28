
function solrpanel() {
  ssh -L $3:localhost:$2 $1
}
