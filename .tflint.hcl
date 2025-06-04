plugin "terraform" {
  enabled = true
  preset = "recommended"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = false
}
