# GitHub OIDC: the workflows get short-lived AWS credentials, so no AWS keys
# are stored in GitHub. An account can have only one provider for this URL.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
