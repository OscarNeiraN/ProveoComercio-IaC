config {
  format = "compact"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Los modulos de esta carpeta son internos: nunca se publican ni se usan fuera de este
# repo, y siempre se instancian desde main.tf, que ya fija las versiones de provider en
# providers.tf. Exigir un required_providers/required_version identico repetido en cada
# modulo hijo es puro boilerplate sin beneficio real en este proyecto.
rule "terraform_required_providers" {
  enabled = false
}

rule "terraform_required_version" {
  enabled = false
}
